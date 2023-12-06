import { Command } from "commander";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { TREASURY_ADDRESS } from "../../constants/important-addresses";
import { readCsv } from "../../utils/file";
import { BulkSendErc20__factory, ERC20__factory } from "../../../../typechain";
import { ethers } from "ethers";

interface DataRow {
  to: string;
  token_symbol: string;
  token_address: string;
  decimals: string;
  amount: string;
}

async function main(chainId: number, inputPath: string, nonce: number) {
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, TREASURY_ADDRESS, deployer);
  const bulkSendErc20 = BulkSendErc20__factory.connect("0x80825A51AFa8bFafe6B0640f605C169c5f58d670", deployer);

  console.log(`[cmds/BulkSendErc20] Proposing a tx to bulk transfer tokens...`);
  console.log(`[cmds/BulkSendErc20] Input path: ${inputPath}`);
  const rows = (await readCsv(inputPath)) as DataRow[];

  const tokenAddresses = rows.map((row) => row.token_address);
  const distinctTokenAddresses = [...new Set(tokenAddresses)];
  for (const tokenAddress of distinctTokenAddresses) {
    const erc20 = ERC20__factory.connect(tokenAddress, deployer);
    const allowance = await erc20.allowance(safeWrapper.getAddress(), bulkSendErc20.address);
    if (allowance.eq(0)) {
      console.log(`[cmds/BulkSendErc20] Proposing tx to approve ${bulkSendErc20.address} to spend ${tokenAddress}...`);
      const tx = await safeWrapper.proposeTransaction(
        ethers.utils.getAddress(erc20.address),
        0,
        erc20.interface.encodeFunctionData("approve", [bulkSendErc20.address, ethers.constants.MaxUint256])
      );
      console.log(`[cmds/BulkSendErc20] Proposed tx: ${tx}`);
    }
  }

  const tokenAmounts = rows.map((row) => ethers.utils.parseUnits(row.amount.replace(",", ""), row.decimals));
  const recepients = rows.map((row) => ethers.utils.getAddress(row.to));

  console.log(`[cmds/BulkSendErc20] Proposing tx to bulk transfer tokens...`);
  const tx = await safeWrapper.proposeTransaction(
    bulkSendErc20.address,
    0,
    bulkSendErc20.interface.encodeFunctionData("leggo", [tokenAddresses, recepients, tokenAmounts]),
    { nonce: nonce++ }
  );
  console.log(`[cmds/BulkSendErc20] Proposed tx: ${tx}`);
}

const program = new Command();

program.requiredOption("--chain-id <number>", "chain id", parseInt);
program.requiredOption("--input-path <string>", "input path");
program.requiredOption("--nonce <number>", "nonce", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId, opts.inputPath, opts.nonce)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

import { Command } from "commander";
import SafeWrapper from "../../wrappers/SafeWrapper";
import signers from "../../entities/signers";
import { TREASURY_ADDRESS } from "../../constants/important-addresses";
import { readCsv } from "../../utils/file";
import { ethers } from "ethers";
import { ERC20__factory } from "../../../../typechain";

interface DataRow {
  to: string;
  token_symbol: string;
  token_address: string;
  decimals: string;
  amount: string;
}

async function main(chainId: number, inputPath: string) {
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, TREASURY_ADDRESS, deployer);

  console.log(`[cmds/Erc20] Proposing multiple txs to transfer tokens...`);
  console.log(`[cmds/Erc20] Input path: ${inputPath}`);
  const rows = (await readCsv(inputPath)) as DataRow[];
  for (const row of rows) {
    console.log(`[cmds/Erc20] Proposing tx to transfer ${row.amount} ${row.token_symbol} to ${row.to}...`);
    const erc20 = ERC20__factory.connect(row.token_address, deployer);
    const amount = ethers.utils.parseUnits(row.amount.replace(",", ""), row.decimals);
    const tx = await safeWrapper.proposeTransaction(
      ethers.utils.getAddress(erc20.address),
      0,
      erc20.interface.encodeFunctionData("transfer", [row.to, amount])
    );
    console.log(`[cmds/Erc20] Proposed tx: ${tx}`);
  }
}

const program = new Command();

program.requiredOption("--chain-id <number>", "chain id", parseInt);
program.requiredOption("--input-path <string>", "input path");

const opts = program.parse(process.argv).opts();

main(opts.chainId, opts.inputPath)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

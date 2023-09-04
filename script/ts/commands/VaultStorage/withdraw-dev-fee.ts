import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { VaultStorage__factory } from "../../../../typechain";
import MultiCall from "@indexed-finance/multicall";
import chains from "../../entities/chains";
import collaterals from "../../entities/collaterals";
import { ethers } from "ethers";
import * as readlineSync from "readline-sync";
import { TREASURY_ADDRESS } from "../../constants/important-addresses";
import SafeWrapper from "../../wrappers/SafeWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const chainInfo = chains[chainId];
  const safeWrapper = new SafeWrapper(chainId, config.safe, signer);

  console.log(`[cmds/VaultStorage] Withdraw dev fee to ${TREASURY_ADDRESS}...`);
  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, signer);
  const multiCall = new MultiCall(chainInfo.jsonRpcProvider);
  const calls = Object.entries(collaterals).map((c) => ({
    target: config.storages.vault,
    function: "devFees",
    args: [c[1].address],
  }));
  const [, devFees] = await multiCall.multiCall(vaultStorage.interface, calls);
  console.table(
    Object.entries(collaterals).map((c, i) => ({
      symbol: c[0],
      devFee: ethers.utils.formatUnits(devFees[i], c[1].decimals),
    }))
  );
  const confirm = readlineSync.question("Confirm to withdraw dev fee? (y/n): ");
  switch (confirm.toLowerCase()) {
    case "y":
      break;
    case "n":
      console.log("Withdraw dev fee cancelled!");
      return;
    default:
      console.log("Invalid input!");
      return;
  }

  let i = 0;
  for (const [key, c] of Object.entries(collaterals)) {
    const tx = await safeWrapper.proposeTransaction(
      vaultStorage.address,
      0,
      vaultStorage.interface.encodeFunctionData("withdrawDevFee", [c.address, devFees[i], TREASURY_ADDRESS])
    );
    console.log(
      `[cmds/VaultStorage] Proposed tx to withdraw ${ethers.utils.formatUnits(devFees[i++], c.decimals)} ${key}: ${tx}`
    );
  }

  console.log("[cmds/VaultStorage] Finished");
}

const program = new Command();

program.requiredOption("--chain-id <chain-id>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

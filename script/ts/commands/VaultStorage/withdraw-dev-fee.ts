import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { EcoPyth2__factory, VaultStorage__factory } from "../../../../typechain";
import MultiCall from "@indexed-finance/multicall";
import chains from "../../entities/chains";
import collaterals from "../../entities/collaterals";
import { ethers } from "ethers";
import * as readlineSync from "readline-sync";
import { TREASURY_ADDRESS } from "../../constants/important-addresses";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { IMultiContractCall } from "../../wrappers/MulticallWrapper/interface";
import { MulticallWrapper } from "../../wrappers/MulticallWrapper";
import { PythEvmPriceStruct } from "../../entities/pyth";

async function main(chainId: number, nonce?: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const multicallWrapper = new MulticallWrapper(config.multicall, signer);
  const safeWrapper = new SafeWrapper(chainId, config.safe, signer);

  console.log(`[cmds/VaultStorage] Withdraw dev fee to ${TREASURY_ADDRESS}...`);
  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, signer);
  const ecoPyth = EcoPyth2__factory.connect(config.oracles.ecoPyth2!, signer);
  const calls = Object.entries(collaterals).reduce((acc, c) => {
    acc.push({
      contract: vaultStorage,
      function: "devFees",
      params: [c[1].address],
    });
    acc.push({
      contract: ecoPyth,
      function: "getPriceUnsafe",
      params: [c[1].assetId],
    });
    return acc;
  }, [] as Array<IMultiContractCall>);
  const ret = await multicallWrapper.multiContractCall<Array<ethers.BigNumber | PythEvmPriceStruct>>(calls);
  const nicelyFormatted = Object.entries(collaterals).map((c, i) => {
    const offset = i * 2;
    const devFee = ret[offset] as ethers.BigNumber;
    const price = (ret[offset + 1] as PythEvmPriceStruct).price;
    const value = devFee.mul(price).div(1e8);
    return {
      symbol: c[0],
      devFee: ethers.utils.formatUnits(devFee, c[1].decimals),
      value: ethers.utils.formatUnits(value, c[1].decimals),
    };
  });
  console.table(nicelyFormatted);
  const totalValue = nicelyFormatted.reduce((acc, c) => {
    return acc + parseFloat(c.value);
  }, 0);
  console.log(`Total dev fee in USD: ${totalValue}`);
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
    const offset = i * 2;
    if ((ret[offset] as ethers.BigNumber).isZero()) {
      console.log(`[cmds/VaultStorage] No dev fee for ${key}`);
      i++;
      continue;
    }
    const tx = await safeWrapper.proposeTransaction(
      vaultStorage.address,
      0,
      vaultStorage.interface.encodeFunctionData("withdrawDevFee", [
        c.address,
        ret[offset] as ethers.BigNumber,
        TREASURY_ADDRESS,
      ]),
      { nonce }
    );
    if (nonce != undefined) {
      nonce++;
    }
    console.log(
      `[cmds/VaultStorage] Proposed tx to withdraw ${ethers.utils.formatUnits(
        ret[offset] as ethers.BigNumber,
        c.decimals
      )} ${key}: ${tx}`
    );
    i++;
  }

  console.log("[cmds/VaultStorage] Finished");
}

const program = new Command();

program.requiredOption("--chain-id <chain-id>", "chain id", parseInt);
program.option("--nonce <nonce>", "nonce", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId, opts.nonce)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

import { Command } from "commander";
import { VaultStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import chains from "../../entities/chains";
import collaterals from "../../entities/collaterals";
import MultiCall from "@indexed-finance/multicall";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;
  const multicall = new MultiCall(provider);

  const multicallCalldata = [];
  for (const [, collateral] of Object.entries(collaterals)) {
    multicallCalldata.push({ target: config.storages.vault, function: "protocolFees", args: [collateral.address] });
  }

  const [, devFees] = await multicall.multiCall(VaultStorage__factory.createInterface(), multicallCalldata);

  console.table(
    Object.entries(collaterals).map(([symbol, collateral], i) => ({
      symbol,
      devFees: ethers.utils.formatUnits(devFees[i], collateral.decimals),
    }))
  );
}

const program = new Command();

program.requiredOption("--chain-id <chain-id>", "chain id", parseInt);

const options = program.parse(process.argv).opts();

main(options.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import chains from "../../entities/chains";
import { CalcPriceLens__factory, Calculator__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;

  const calcPriceLEns = CalcPriceLens__factory.connect(config.oracles.calcPriceLens, provider);
  const calculator = Calculator__factory.connect(config.calculator, provider);
  console.log((await calculator.getAUME30(true)).toString());
  console.log((await calculator.getHLPValueE30(true)).toString());
  // const price = await calcPriceLEns["getPrice(bytes32,uint256[])"](ethers.utils.formatBytes32String("ybUSDB"), [
  //   "2809970000000000000000000000000000",
  // ]);
  // console.log("price", price.toString());
}

const program = new Command();

program.requiredOption("--chain-id <number>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

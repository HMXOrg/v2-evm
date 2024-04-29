import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { LiquidityHandler__factory, ERC20__factory, MockErc20__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);

  const tokenAddress = config.tokens.wusdm;
  const amount = ethers.utils.parseUnits("1000000", 18);
  const mintTo = "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a";

  console.log("[MockErc20] mint...");
  const token = MockErc20__factory.connect(tokenAddress, signer);
  await (await token.mint(mintTo, amount)).wait();
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

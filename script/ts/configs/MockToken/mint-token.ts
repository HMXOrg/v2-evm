import { ethers } from "hardhat";
import { MockErc20__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const receiver = "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a";
const mintAmount = ethers.utils.parseUnits("2000000", 6);

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const token = MockErc20__factory.connect(config.tokens.usdcCircle, deployer);

  console.log("> Mint Token...");
  await (await token.mint(receiver, mintAmount)).wait();
  console.log("> Mint Token success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

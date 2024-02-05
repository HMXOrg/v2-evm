import { ethers } from "hardhat";
import { HLP__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const minter = config.services.liquidity;

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const hlp = HLP__factory.connect(config.tokens.hlp, deployer);

  console.log("> HLP Set Minter...");
  await (await hlp.setMinter(minter, true)).wait();
  console.log("> HLP Set Minter success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

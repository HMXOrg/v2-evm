import { ethers } from "hardhat";
import { HLP__factory } from "../../../../typechain";
import { getConfig, loadConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const config = loadConfig(chainId);

  const minter = config.services.liquidity;

  const deployer = (await ethers.getSigners())[0];
  const hlp = HLP__factory.connect(config.tokens.hlp, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log("[configs/HLP] Set Minter...");
  await ownerWrapper.authExec(hlp.address, hlp.interface.encodeFunctionData("setMinter", [minter, true]));
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

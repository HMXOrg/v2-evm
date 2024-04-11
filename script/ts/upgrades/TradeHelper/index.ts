import { ethers, run, tenderly, upgrades } from "hardhat";
import { getConfig } from "../../utils/config";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const TradeHelper = await ethers.getContractFactory("TradeHelper", deployer);
  const tradeHelperAddress = config.helpers.trade;

  console.log(`[upgrade/TradeHelper] Preparing to upgrade TradeHelper`);
  const newImplementation = await upgrades.prepareUpgrade(tradeHelperAddress, TradeHelper);
  console.log(`[upgrade/TradeHelper] Done`);

  console.log(`[upgrade/TradeHelper] New TradeHelper Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(tradeHelperAddress, newImplementation.toString());
  console.log(`[upgrade/TradeHelper] Done`);

  console.log(`[upgrade/TradeHelper] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "TradeHelper",
  });

  console.log(`[upgrade/TradeHelper] Verify contract`);
  await run("verify:verify", {
    address: newImplementation.toString(),
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

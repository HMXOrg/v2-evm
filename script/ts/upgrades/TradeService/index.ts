import { ethers, run, tenderly, upgrades } from "hardhat";
import { getConfig } from "../../utils/config";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const config = getConfig();
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const deployer = (await ethers.getSigners())[0];
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const TradeService = await ethers.getContractFactory("TradeService", deployer);
  const tradeServiceAddress = config.services.trade;

  console.log(`[upgrade/TradeService] Preparing to upgrade TradeService`);
  const newImplementation = await upgrades.prepareUpgrade(tradeServiceAddress, TradeService);
  console.log(`[upgrade/TradeService] Done`);

  console.log(`[upgrade/TradeService] New TradeService Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(tradeServiceAddress, newImplementation.toString());
  console.log(`[upgrade/TradeService] Done`);

  console.log(`[upgrade/TradeService] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "TradeService",
  });

  console.log(`[upgrades/TradeService] Verify contract on Etherscan`);
  await run("verify:verify", {
    address: newImplementation.toString(),
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

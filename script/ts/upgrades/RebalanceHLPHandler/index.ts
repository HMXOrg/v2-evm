import { tenderly, upgrades, getChainId } from "hardhat";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";
import { RebalanceHLPHandler__factory } from "../../../../typechain";

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const RebalanceHLPHandler = new RebalanceHLPHandler__factory(deployer);
  const rebalanceHLPHandler = config.handlers.rebalanceHLP;

  console.log(`[upgrade/RebalanceHLPHandler] Preparing to upgrade RebalanceHLPHandler`);
  const newImplementation = await upgrades.prepareUpgrade(rebalanceHLPHandler, RebalanceHLPHandler);
  console.log(`[upgrade/RebalanceHLPHandler] Done`);

  console.log(`[upgrade/RebalanceHLPHandler] New RebalanceHLPHandler Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(rebalanceHLPHandler, newImplementation.toString());
  console.log(`[upgrade/RebalanceHLPHandler] Upgraded!`);

  console.log(`[upgrade/RebalanceHLPHandler] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "RebalanceHLPHandler",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

import { tenderly, upgrades, getChainId } from "hardhat";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";
import { RebalanceHLPService__factory } from "../../../../typechain";

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const RebalanceHLPService = new RebalanceHLPService__factory(deployer);
  const rebalanceHLPService = config.services.rebalanceHLP;

  console.log(`[upgrade/RebalanceHLPService] Preparing to upgrade RebalanceHLPService`);
  const newImplementation = await upgrades.prepareUpgrade(rebalanceHLPService, RebalanceHLPService);
  console.log(`[upgrade/RebalanceHLPService] Done`);

  console.log(`[upgrade/RebalanceHLPService] New RebalanceHLPService Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(rebalanceHLPService, newImplementation.toString());
  console.log(`[upgrade/RebalanceHLPService] Upgraded!`);

  console.log(`[upgrade/RebalanceHLPService] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "RebalanceHLPService",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

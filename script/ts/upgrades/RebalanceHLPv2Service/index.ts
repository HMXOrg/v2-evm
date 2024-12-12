import { tenderly, upgrades, getChainId } from "hardhat";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";
import { RebalanceHLPv2Service__factory } from "../../../../typechain";

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const RebalanceHLPv2Service = new RebalanceHLPv2Service__factory(deployer);
  const rebalanceHLPv2Service = config.services.rebalanceHLPv2;

  console.log(`[upgrade/RebalanceHLPv2Service] Preparing to upgrade RebalanceHLPv2Service`);
  const newImplementation = await upgrades.prepareUpgrade(rebalanceHLPv2Service, RebalanceHLPv2Service);
  console.log(`[upgrade/RebalanceHLPv2Service] Done`);

  console.log(`[upgrade/RebalanceHLPv2Service] New RebalanceHLPv2Service Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(rebalanceHLPv2Service, newImplementation.toString());
  console.log(`[upgrade/RebalanceHLPv2Service] Upgraded!`);

  console.log(`[upgrade/RebalanceHLPv2Service] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "RebalanceHLPv2Service",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

import { ethers, run, tenderly, upgrades } from "hardhat";
import { getConfig } from "../../utils/config";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const config = getConfig();
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const deployer = (await ethers.getSigners())[0];
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const Calculator = await ethers.getContractFactory("Calculator", deployer);
  const calculatorAddress = config.calculator;

  console.log(`[upgrade/Calculator] Preparing to upgrade Calculator`);
  const newImplementation = await upgrades.prepareUpgrade(calculatorAddress, Calculator);
  console.log(`[upgrade/Calculator] Done`);

  console.log(`[upgrade/Calculator] New Calculator Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(calculatorAddress, newImplementation.toString());
  console.log(`[upgrade/Calculator] Done`);

  console.log(`[upgrade/Calculator] Verify contract on Tenderly`);
  await tenderly.verify({
    address: newImplementation.toString(),
    name: "Calculator",
  });

  console.log(`[upgrades/Calculator] Verify contract on Etherscan`);
  await run("verify:verify", {
    address: newImplementation.toString(),
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

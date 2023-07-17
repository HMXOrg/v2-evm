import { ethers, tenderly, upgrades, getChainId, network } from "hardhat";
import { loadConfig, writeConfigFile } from "../../utils/config";
import signers from "../../entities/signers";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  const LimitTradeHandler = await ethers.getContractFactory("LimitTradeHandler", deployer);

  const minExecutionFee = ethers.utils.parseEther("0.0003"); // 0.0003 ether
  const minExecutionTimestamp = 60 * 60 * 5; // 5 minutes

  console.log(`[upgrade/LimitTradeHandler] Deploying`);
  const contract = await upgrades.deployProxy(
    LimitTradeHandler,
    [config.tokens.weth, config.services.trade, config.oracles.ecoPyth, minExecutionFee, minExecutionTimestamp],
    {
      unsafeAllow: ["delegatecall"],
    }
  );
  config.handlers.limitTrade = contract.address;
  writeConfigFile(config);
  console.log(`[upgrade/LimitTradeHandler] Deployed!`);

  console.log(`[upgrade/LimitTradeHandler] Verify contract on Tenderly`);
  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "LimitTradeHandler",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

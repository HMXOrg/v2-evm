import { ethers, tenderly, upgrades, getChainId } from "hardhat";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const LimitTradeHandler = await ethers.getContractFactory("LimitTradeHandler", deployer);
  const limitTradeHandler = config.handlers.limitTrade;

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
  console.log(`[upgrade/LimitTradeHandler] Deployed!`);

  console.log(`[upgrade/LimitTradeHandler] Verify contract on Tenderly`);
  await tenderly.verify({
    address: contract.address,
    name: "LimitTradeHandler",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

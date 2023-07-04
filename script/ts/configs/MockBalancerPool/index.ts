import { ethers } from "hardhat";
import {
  LiquidityHandler__factory,
  MockBalancerPool__factory,
  MockBalancerVault__factory,
} from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const pool = MockBalancerPool__factory.connect("0xcFefE08aD33362195B1BE3a2e1232f675e5d6b16", deployer);
  const vault = MockBalancerVault__factory.connect("0x2a873B368C311e0cdaf985730A5aC4740998bF87", deployer);
  (await pool.setNormalizedWeights([ethers.utils.parseEther("0.8"), ethers.utils.parseEther("0.2")])).wait();
  (await pool.setSwapFeePercentage(ethers.utils.parseEther("0.01"))).wait();
  (await pool.setVault("0x2a873B368C311e0cdaf985730A5aC4740998bF87")).wait();
  await vault.setParams(
    ["0x7d43368A1D4a134d00463BfCe1ebb98209B16573", config.tokens.usdc],
    [ethers.utils.parseUnits("800000", 18), ethers.utils.parseUnits("400000", 6)]
  );
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

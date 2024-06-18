import { ethers, run } from "hardhat";
import { BulkSendErc20__factory } from "../../../../typechain";

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log(`[deploy/BulkSendErc20] Deploying BulkSendErc20`);
  const BulkSendErc20 = new BulkSendErc20__factory(deployer);
  const bulkSendErc20 = await BulkSendErc20.deploy();
  await bulkSendErc20.deployed();
  console.log(`[deploy/BulkSendErc20] Deployed at: ${bulkSendErc20.address}`);

  await run("verify:verify", {
    address: bulkSendErc20.address,
    constructorArguments: [],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

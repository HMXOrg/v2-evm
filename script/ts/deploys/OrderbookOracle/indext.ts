import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying OrderbookOracle Contract`);
  const OrderbookOracle = await ethers.getContractFactory("OrderbookOracle", deployer);
  const orderbookOracle = await OrderbookOracle.deploy();
  await orderbookOracle.deployed();
  console.log(`Deployed at: ${orderbookOracle.address}`);

  config.oracles.orderbook = orderbookOracle.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: orderbookOracle.address,
    name: "OrderbookOracle",
  });
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

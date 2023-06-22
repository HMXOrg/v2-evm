import { ethers } from "hardhat";
import { EcoPyth__factory } from "../../../../typechain";
import { getConfig } from "../../../../deploy/utils/config";
import { getUpdatePriceData } from "../../../../deploy/utils/price";
import { ecoPythPriceFeedIdsByIndex } from "../../constants/eco-pyth-index";
import * as readlineSync from "readline-sync";

async function main() {
  // https://xc-mainnet.pyth.network
  // https://xc-testnet.pyth.network
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  const pyth = EcoPyth__factory.connect(config.oracles.ecoPyth, deployer);

  const [minPublishedTime, priceUpdateData, publishTimeDiffUpdateData, hashedVaas] = await getUpdatePriceData(
    ecoPythPriceFeedIdsByIndex
  );
  const confirm = readlineSync.question("Confirm to update price feeds? (y/n): ");
  switch (confirm) {
    case "y":
      break;
    case "n":
      console.log("Feed Price cancelled!");
      return;
    default:
      console.log("Invalid input!");
      return;
  }

  console.log("Feed Price...");
  console.log("Allow deployer to update price feeds...");
  await (await pyth.setUpdater(deployer.address, true)).wait();
  console.log("Update price feeds...");
  await (await pyth.updatePriceFeeds(priceUpdateData, publishTimeDiffUpdateData, minPublishedTime, hashedVaas)).wait();
  console.log("Disallow deployer to update price feeds...");
  await (await pyth.setUpdater(deployer.address, false)).wait();
  console.log("Feed Price success!");
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

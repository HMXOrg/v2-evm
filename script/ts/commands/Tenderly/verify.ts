import { ethers, tenderly } from "hardhat";
import { loadConfig } from "../../utils/config";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const config = loadConfig(chainId);
  const address = config.oracles.unsafeEcoPythCalldataBuilder;
  await tenderly.verify({
    address,
    name: "UnsafeEcoPythCalldataBuilder",
  });
}

main()
  .then(() => {
    process.exitCode = 0;
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

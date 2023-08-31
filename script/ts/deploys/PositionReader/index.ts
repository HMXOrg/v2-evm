import { ethers, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("PositionReader", deployer);
  const contract = await Contract.deploy(
    "0x439860Bea87C4De1757e30Cb4073578CE450Cbbd",
    "0x58120a4f1959D1670e84BBBc1C403e08cD152bae",
    "0x0DbdfF9CeE7cA35C8bcd48B031f8C2aB274F4552",
    "0xCd6a5d5D7028D3EF48e25B626180b256EF901C4a"
    // config.storages.config,
    // config.storages.perp,
    // config.oracles.middleware,
    // config.calculator
  );
  await contract.deployed();
  console.log(`Deploying PositionReader Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.reader.position = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: contract.address,
    name: "PositionReader",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

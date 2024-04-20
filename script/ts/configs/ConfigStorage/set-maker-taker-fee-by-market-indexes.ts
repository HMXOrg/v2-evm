import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);

  const forexFees = {
    makerFee: 5000, // 0.005%
    takerFee: 25000, // 0.025%
  };

  const commoditiesFees = {
    makerFee: 35000, // 0.035%
    takerFee: 75000, // 0.075%
  };
  const cryptoFees = {
    makerFee: 35000, // 0.035%
    takerFee: 75000, // 0.075%
  };

  const inputs = [
    {
      marketIndex: 0, // ETHUSD
      makerFee: 20000, // 0.02%
      takerFee: 40000, // 0.04%
    },
    {
      marketIndex: 1, // BTCUSD
      makerFee: 10000, // 0.01%
      takerFee: 40000, // 0.04%
    },
    {
      marketIndex: 3, // JPYUSD
      ...forexFees,
    },
    {
      marketIndex: 4, // XAUUSD
      ...commoditiesFees,
    },
    {
      marketIndex: 8, // EURUSD
      ...forexFees,
    },
    {
      marketIndex: 9, // XAGUSD
      ...commoditiesFees,
    },
    {
      marketIndex: 10, // AUDUSD
      ...forexFees,
    },
    {
      marketIndex: 11, // GBPUSD
      ...forexFees,
    },
    {
      marketIndex: 12, // ADAUSD
      ...cryptoFees,
    },
    {
      marketIndex: 13, // MATICUSD
      ...cryptoFees,
    },
    {
      marketIndex: 14, // SUIUSD
      ...cryptoFees,
    },
    {
      marketIndex: 15, // ARBUSD
      ...cryptoFees,
    },
    {
      marketIndex: 16, // OPUSD
      ...cryptoFees,
    },
    {
      marketIndex: 17, // LTCUSD
      ...cryptoFees,
    },
    {
      marketIndex: 20, // BNBUSD
      ...cryptoFees,
    },
    {
      marketIndex: 21, // SOLUSD
      ...cryptoFees,
    },
    {
      marketIndex: 23, // XRPUSD
      ...cryptoFees,
    },
    {
      marketIndex: 25, // LINKUSD
      ...cryptoFees,
    },
    {
      marketIndex: 26, // USDCHF
      ...forexFees,
    },
    {
      marketIndex: 27, // DOGEUSD
      ...cryptoFees,
    },
    {
      marketIndex: 28, // USDCAD
      ...forexFees,
    },
    {
      marketIndex: 29, // USDSGD
      ...forexFees,
    },
    {
      marketIndex: 30, // USDCNH
      ...forexFees,
    },
    {
      marketIndex: 31, // USDHKD
      ...forexFees,
    },
    {
      marketIndex: 32, // BCHUSD
      ...cryptoFees,
    },
    {
      marketIndex: 33, // MEMEUSD
      ...cryptoFees,
    },
    {
      marketIndex: 34, // DIX
      ...forexFees,
    },
    {
      marketIndex: 35, // JTOUSD
      ...cryptoFees,
    },
    {
      marketIndex: 36, // STXUSD
      ...cryptoFees,
    },
    {
      marketIndex: 37, // ORDIUSD
      ...cryptoFees,
    },
    {
      marketIndex: 38, // TIAUSD
      ...cryptoFees,
    },
    {
      marketIndex: 39, // AVAXUSD
      ...cryptoFees,
    },
    {
      marketIndex: 40, // INJUSD
      ...cryptoFees,
    },
    {
      marketIndex: 41, // DOTUSD
      ...cryptoFees,
    },
    {
      marketIndex: 42, // SEIUSD
      ...cryptoFees,
    },
    {
      marketIndex: 43, // ATOMUSD
      ...cryptoFees,
    },
    {
      marketIndex: 44, // 1000PEPEUSD
      ...cryptoFees,
    },
    {
      marketIndex: 45, // 1000SHIBUSD
      ...cryptoFees,
    },
    {
      marketIndex: 46, // USDSEK
      ...forexFees,
    },
    {
      marketIndex: 47, // ICPUSD
      ...cryptoFees,
    },
    {
      marketIndex: 48, // MANTAUSD
      ...cryptoFees,
    },
    {
      marketIndex: 49, // STRKUSD
      ...cryptoFees,
    },
    {
      marketIndex: 50, // PYTHUSD
      ...cryptoFees,
    },
    {
      marketIndex: 51, // PENDLEUSD
      ...cryptoFees,
    },
    {
      marketIndex: 52, // WUSD
      ...cryptoFees,
    },
    {
      marketIndex: 53, // ENAUSD
      ...cryptoFees,
    },
  ];

  const deployer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[config/ConfigStorage] Set Maker/Taker Fee...");
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setMakerTakerFeeByMarketIndexes", [
      inputs.map((e) => e.marketIndex),
      inputs.map((e) => e.makerFee),
      inputs.map((e) => e.takerFee),
    ])
  );
  console.log("[config/ConfigStorage] Done");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

const opts = prog.parse(process.argv).opts();

main(opts.chainId).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

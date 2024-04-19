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
      marketIndex: 2, // JPYUSD
      ...forexFees,
    },
    {
      marketIndex: 3, // XAUUSD
      ...commoditiesFees,
    },
    {
      marketIndex: 4, // EURUSD
      ...forexFees,
    },
    {
      marketIndex: 5, // XAGUSD
      ...commoditiesFees,
    },
    {
      marketIndex: 6, // AUDUSD
      ...forexFees,
    },
    {
      marketIndex: 7, // GBPUSD
      ...forexFees,
    },
    {
      marketIndex: 8, // ADAUSD
      ...cryptoFees,
    },
    {
      marketIndex: 9, // MATICUSD
      ...cryptoFees,
    },
    {
      marketIndex: 10, // SUIUSD
      ...cryptoFees,
    },
    {
      marketIndex: 11, // ARBUSD
      ...cryptoFees,
    },
    {
      marketIndex: 12, // OPUSD
      ...cryptoFees,
    },
    {
      marketIndex: 13, // LTCUSD
      ...cryptoFees,
    },
    {
      marketIndex: 14, // BNBUSD
      ...cryptoFees,
    },
    {
      marketIndex: 15, // SOLUSD
      ...cryptoFees,
    },
    {
      marketIndex: 16, // XRPUSD
      ...cryptoFees,
    },
    {
      marketIndex: 17, // LINKUSD
      ...cryptoFees,
    },
    {
      marketIndex: 18, // USDCHF
      ...forexFees,
    },
    {
      marketIndex: 19, // DOGEUSD
      ...cryptoFees,
    },
    {
      marketIndex: 20, // USDCAD
      ...forexFees,
    },
    {
      marketIndex: 21, // USDSGD
      ...forexFees,
    },
    {
      marketIndex: 22, // USDCNH
      ...forexFees,
    },
    {
      marketIndex: 23, // USDHKD
      ...forexFees,
    },
    {
      marketIndex: 24, // BCHUSD
      ...cryptoFees,
    },
    {
      marketIndex: 25, // MEMEUSD
      ...cryptoFees,
    },
    {
      marketIndex: 26, // DIX
      ...forexFees,
    },
    {
      marketIndex: 27, // JTOUSD
      ...cryptoFees,
    },
    {
      marketIndex: 28, // STXUSD
      ...cryptoFees,
    },
    {
      marketIndex: 29, // ORDIUSD
      ...cryptoFees,
    },
    {
      marketIndex: 30, // TIAUSD
      ...cryptoFees,
    },
    {
      marketIndex: 31, // AVAXUSD
      ...cryptoFees,
    },
    {
      marketIndex: 32, // INJUSD
      ...cryptoFees,
    },
    {
      marketIndex: 33, // DOTUSD
      ...cryptoFees,
    },
    {
      marketIndex: 34, // SEIUSD
      ...cryptoFees,
    },
    {
      marketIndex: 35, // ATOMUSD
      ...cryptoFees,
    },
    {
      marketIndex: 36, // 1000PEPEUSD
      ...cryptoFees,
    },
    {
      marketIndex: 37, // 1000SHIBUSD
      ...cryptoFees,
    },
    {
      marketIndex: 38, // USDSEK
      ...forexFees,
    },
    {
      marketIndex: 39, // ICPUSD
      ...cryptoFees,
    },
    {
      marketIndex: 40, // MANTAUSD
      ...cryptoFees,
    },
    {
      marketIndex: 41, // STRKUSD
      ...cryptoFees,
    },
    {
      marketIndex: 42, // PYTHUSD
      ...cryptoFees,
    },
    {
      marketIndex: 43, // PENDLEUSD
      ...cryptoFees,
    },
    {
      marketIndex: 44, // WUSD
      ...cryptoFees,
    },
    {
      marketIndex: 45, // ENAUSD
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

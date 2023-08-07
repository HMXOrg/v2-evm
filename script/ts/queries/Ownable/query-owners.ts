import { ethers } from "ethers";
import chains from "../../entities/chains";
import { loadConfig } from "../../utils/config";
import MultiCall from "@indexed-finance/multicall";
import { OwnableUpgradeable__factory } from "../../../../typechain";

async function main() {
  const chain = chains[42161];
  const config = loadConfig(42161);
  const provider = new ethers.providers.JsonRpcProvider(chain.rpc);
  const multicall = new MultiCall(provider);

  const inputs = [
    { target: config.timelock, function: "owner", args: [] },
    { target: config.storages.config, function: "owner", args: [] },
    { target: config.storages.perp, function: "owner", args: [] },
    { target: config.storages.vault, function: "owner", args: [] },
    { target: config.handlers.bot, function: "owner", args: [] },
    { target: config.handlers.crossMargin, function: "owner", args: [] },
    { target: config.handlers.limitTrade, function: "owner", args: [] },
    { target: config.handlers.liquidity, function: "owner", args: [] },
    { target: config.oracles.ecoPyth, function: "owner", args: [] },
    { target: config.oracles.ecoPyth2, function: "owner", args: [] },
    { target: config.oracles.ecoPythCalldataBuilder, function: "owner", args: [] },
    { target: config.oracles.middleware, function: "owner", args: [] },
    { target: config.oracles.pythAdapter, function: "owner", args: [] },
    { target: config.oracles.sglpStakedAdapter, function: "owner", args: [] },
    { target: config.oracles.unsafeEcoPythCalldataBuilder, function: "owner", args: [] },
    { target: config.tokens.hlp, function: "owner", args: [] },
    { target: config.strategies.stakedGlpStrategy, function: "owner", args: [] },
    { target: config.strategies.convertedGlpStrategy, function: "owner", args: [] },
    { target: config.calculator, function: "owner", args: [] },
    { target: config.rewardDistributor, function: "owner", args: [] },
  ];

  const [, owners] = await multicall.multiCall(OwnableUpgradeable__factory.createInterface(), inputs);
  console.table({
    timelock: owners[0],
    configStorage: owners[1],
    perpStorage: owners[2],
    vaultStorage: owners[3],
    botHandler: owners[4],
    crossMarginHandler: owners[5],
    limitTradeHandler: owners[6],
    liquidityHandler: owners[7],
    ecoPyth: owners[8],
    ecoPyth2: owners[9],
    ecoPythCalldataBuilder: owners[10],
    oracleMiddleware: owners[11],
    pythAdapter: owners[12],
    sglpStakedAdapter: owners[13],
    unsafeEcoPythCalldataBuilder: owners[14],
    hlp: owners[15],
    stakedGlpStrategy: owners[16],
    convertedGlpStrategy: owners[17],
    calculator: owners[18],
    rewardDistributor: owners[19],
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

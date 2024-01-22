import {
  BotHandler__factory,
  CrossMarginHandler__factory,
  LimitTradeHandler__factory,
  LiquidityHandler__factory,
  PythAdapter__factory,
} from "../../../../typechain";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main() {
  const config = loadConfig(42161);

  const NEW_PYTH = config.oracles.ecoPyth2;

  const deployer = signers.deployer(42161);
  const ownerWrapper = new OwnerWrapper(42161, deployer);

  const pythAdapter = PythAdapter__factory.connect(config.oracles.pythAdapter, deployer);
  const botHandler = BotHandler__factory.connect(config.handlers.bot, deployer);
  const crossMarginHandler = CrossMarginHandler__factory.connect(config.handlers.crossMargin, deployer);
  const limitTradeHandler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  const liquidityHandler = LiquidityHandler__factory.connect(config.handlers.liquidity, deployer);

  const prepTxs = [
    {
      address: pythAdapter.address,
      calldata: pythAdapter.interface.encodeFunctionData("setPyth", [NEW_PYTH]),
    },
    {
      address: botHandler.address,
      calldata: botHandler.interface.encodeFunctionData("setPyth", [NEW_PYTH]),
    },
    {
      address: crossMarginHandler.address,
      calldata: crossMarginHandler.interface.encodeFunctionData("setPyth", [NEW_PYTH]),
    },
    {
      address: limitTradeHandler.address,
      calldata: limitTradeHandler.interface.encodeFunctionData("setPyth", [NEW_PYTH]),
    },
    {
      address: liquidityHandler.address,
      calldata: liquidityHandler.interface.encodeFunctionData("setPyth", [NEW_PYTH]),
    },
  ];

  console.log("[config/Multi/setPyth] Set Pyth on multiple contracts...");
  for (const tx of prepTxs) {
    await ownerWrapper.authExec(tx.address, tx.calldata);
  }
  console.log("[config/Multi/setPyth] Done");
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

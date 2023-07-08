import {
  BotHandler__factory,
  CrossMarginHandler__factory,
  LimitTradeHandler__factory,
  LiquidityHandler__factory,
  PythAdapter__factory,
} from "../../../../typechain";
import signers from "../../entities/signers";
import { loadConfig } from "../../utils/config";

async function main() {
  const config = loadConfig(42161);

  const NEW_PYTH = config.oracles.ecoPyth2;

  const deployer = signers.deployer(42161);

  const pythAdapter = PythAdapter__factory.connect(config.oracles.pythAdapter, deployer);
  const botHandler = BotHandler__factory.connect(config.handlers.bot, deployer);
  const crossMarginHandler = CrossMarginHandler__factory.connect(config.handlers.crossMargin, deployer);
  const limitTradeHandler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  const liquidityHandler = LiquidityHandler__factory.connect(config.handlers.liquidity, deployer);

  let nonce = await deployer.getTransactionCount();

  console.log("[config/Multi/setPyth] Set Pyth on multiple contracts...");
  const promises = [];
  promises.push(pythAdapter.setPyth(NEW_PYTH, { nonce: nonce++ }));
  promises.push(botHandler.setPyth(NEW_PYTH, { nonce: nonce++ }));
  promises.push(crossMarginHandler.setPyth(NEW_PYTH, { nonce: nonce++ }));
  promises.push(limitTradeHandler.setPyth(NEW_PYTH, { nonce: nonce++ }));
  promises.push(liquidityHandler.setPyth(NEW_PYTH, { nonce: nonce++ }));
  const txs = await Promise.all(promises);
  console.log(`[config/Multi/setPyth] Txs: ${txs.map((tx) => tx.hash).join(",")}`);
  await txs[txs.length - 1].wait(1);
  console.log("[config/Multi/setPyth] Finished");
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { LimitTradeHandler__factory, ERC20__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const signerAddress = await signer.getAddress();

  const subAccountId = 0;
  const marketIndex = 0;
  const sizeDelta = ethers.utils.parseUnits("1000", 30);
  const triggerPrice = 0;
  const acceptablePrice = ethers.utils.parseUnits("100000000000", 30);
  const triggerAboveThreshold = true;
  const reduceOnly = false;
  const tpToken = config.tokens.usdt;

  console.log("[LimitTradeHandler] Create Trade Order...");
  const handler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, signer);
  const executionFee = await handler.minExecutionFee();
  const tx = await handler["createOrder(address,uint8,uint256,int256,uint256,uint256,bool,uint256,bool,address)"](
    signerAddress,
    subAccountId,
    marketIndex,
    sizeDelta,
    triggerPrice,
    acceptablePrice,
    triggerAboveThreshold,
    executionFee,
    reduceOnly,
    tpToken,
    { value: executionFee }
  );
  console.log(`[LimitTradeHandler] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log(`orderIndex: ${(await handler.limitOrdersIndex(signerAddress)).sub(1)}`);
  console.log("[LimitTradeHandler] Finished");
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

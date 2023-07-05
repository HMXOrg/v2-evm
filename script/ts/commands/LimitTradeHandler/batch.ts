import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { LimitTradeHandler__factory, ERC20__factory } from "../../../../typechain";
import { ethers } from "ethers";

enum OrderType {
  Create,
  Update,
  Cancel,
}

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const signerAddress = await signer.getAddress();
  const abi = ethers.utils.defaultAbiCoder;
  const handler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, signer);

  const mainAccount = signerAddress;
  const subAccountId = 1;
  const marketIndex = 0;
  const executionFee = await handler.minExecutionFee();

  const commands = [OrderType.Create, OrderType.Create];
  const orders = [
    {
      marketIndex,
      sizeDelta: ethers.utils.parseUnits("1000", 30),
      triggerPrice: 0,
      acceptablePrice: ethers.utils.parseUnits("100000000000", 30),
      triggerAboveThreshold: true,
      executionFee,
      reduceOnly: false,
      tpToken: config.tokens.usdc,
    },
    {
      marketIndex,
      sizeDelta: ethers.utils.parseUnits("-1000", 30),
      triggerPrice: 0,
      acceptablePrice: ethers.utils.parseUnits("0", 30),
      triggerAboveThreshold: true,
      executionFee,
      reduceOnly: false,
      tpToken: config.tokens.usdc,
    },
  ].map((each) => {
    return abi.encode(
      [`uint256`, `int256`, `uint256`, `uint256`, `bool`, `uint256`, `bool`, `address`],
      [
        each.marketIndex,
        each.sizeDelta,
        each.triggerPrice,
        each.acceptablePrice,
        each.triggerAboveThreshold,
        each.executionFee,
        each.reduceOnly,
        each.tpToken,
      ]
    );
  });

  console.log("[LimitTradeHandler] batch...");

  const tx = await handler.batch(mainAccount, subAccountId, commands, orders, {
    value: executionFee.mul(orders.length),
    gasLimit: 50000000,
  });
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

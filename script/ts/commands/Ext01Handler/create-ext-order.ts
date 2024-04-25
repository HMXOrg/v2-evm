import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Ext01Handler__factory } from "../../../../typechain";
import { ethers } from "ethers";
import { getSubAccount } from "../../utils/account";

// OrderType 1 = Create switch collateral order
const SWITCH_COLLATERAL_ORDER_TYPE = 1;

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const signerAddress = await signer.getAddress();

  const orderType = SWITCH_COLLATERAL_ORDER_TYPE;
  const mainAccount = "0x6629eC35c8Aa279BA45Dbfb575c728d3812aE31a";
  const subAccountId = 1;
  const amount = ethers.utils.parseUnits("1000", 6);
  const path = [config.tokens.usdc, config.tokens.weth, config.tokens.sglp];
  const minToAmount = 0;
  const data = ethers.utils.defaultAbiCoder.encode(
    ["uint8", "uint248", "address[]", "uint256"],
    [subAccountId, amount, path, minToAmount]
  );

  console.log("[Ext01Handler] create Switch Collateral order...");
  const handler = Ext01Handler__factory.connect(config.handlers.ext01, signer);
  const executionFee = await handler.minExecutionOrderOf(orderType);
  const tx = await handler.createExtOrder(
    {
      orderType: orderType,
      executionFee,
      mainAccount,
      subAccountId,
      data,
    },
    { value: executionFee }
  );
  console.log(`[Ext01Handler] Tx: ${tx.hash}`);
  await tx.wait(1);

  const subAccount = getSubAccount(mainAccount, subAccountId);
  console.log(`orderIndex: ${(await handler.genericOrdersIndex(subAccount)).sub(1)}`);
  console.log("[Ext01Handler] Finished");
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

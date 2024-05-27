import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { CrossMarginHandler__factory } from "../../../../typechain";
import { ethers } from "ethers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, signer);

  const account = "0xbfd5dfd7dccfb83d49d788c71b7ac27a002b3159";
  const subAccountId = 0;
  const token = config.tokens.usdc;
  const amount = ethers.utils.parseUnits("20000", 6);
  const shouldWrap = false;

  console.log("[commands/CrossMarginHandler] depositCollateral...");
  const handler = CrossMarginHandler__factory.connect(config.handlers.crossMargin, signer);
  const executionFee = await handler.minExecutionOrderFee();
  await ownerWrapper.authExec(
    handler.address,
    handler.interface.encodeFunctionData("createWithdrawCollateralOrderOnBehalf", [
      account,
      subAccountId,
      token,
      amount,
      executionFee,
      shouldWrap,
    ]),
    executionFee
  );
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

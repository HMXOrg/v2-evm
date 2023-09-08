import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import chains from "../../entities/chains";
import { Presets, Client } from "userop";
import { ERC20__factory, ERC20, LimitTradeHandler__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const rpcUrl = chains[chainId].rpc;
  const provider = chains[chainId].jsonRpcProvider;
  const signer = signers.deployer(chainId);

  const paymasterRpcUrl = `https://api.stackup.sh/v1/paymaster/${process.env.STACKUP_API_KEY}`;
  const paymasterContext = { type: "payg" };
  const paymaster = Presets.Middleware.verifyingPaymaster(paymasterRpcUrl, paymasterContext);

  // Initialize the Builder
  const builder = await Presets.Builder.SimpleAccount.init(signer, rpcUrl, { paymasterMiddleware: paymaster });
  const aaAccountAddress = await builder.getSender();
  console.log(`Account address: ${aaAccountAddress}`);

  const handler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, signer);
  const limitTradeHandler = new ethers.Contract(config.handlers.limitTrade, LimitTradeHandler__factory.abi, provider);

  const signerAddress = await signer.getAddress();
  const subAccountId = 2;
  const marketIndex = 1;
  const sizeDelta = ethers.utils.parseUnits("100", 30);
  const triggerPrice = 0;
  const acceptablePrice = ethers.utils.parseUnits("100000000000", 30);
  const triggerAboveThreshold = true;
  const reduceOnly = false;
  const tpToken = config.tokens.usdc;
  const executionFee = await handler.minExecutionFee();

  // Create the calls
  await (await handler.setDelegate(aaAccountAddress)).wait();
  const trade = {
    to: config.handlers.limitTrade,
    value: executionFee,
    data: limitTradeHandler.interface.encodeFunctionData(
      "createOrder(address,uint8,uint256,int256,uint256,uint256,bool,uint256,bool,address)",
      [
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
      ]
    ),
  };

  const setDelegate = {
    to: config.handlers.limitTrade,
    value: ethers.constants.Zero,
    data: limitTradeHandler.interface.encodeFunctionData("setDelegate", [aaAccountAddress]),
  };

  const calls = [trade];

  const client = await Client.init(rpcUrl);
  const res = await client.sendUserOperation(
    builder.executeBatch(
      calls.map((each) => each.to),
      calls.map((each) => each.data)
    ),
    {
      onBuild: (op) => console.log("Signed UserOperation:", op),
    }
  );

  console.log(`UserOpHash: ${res.userOpHash}`);
  console.log("Waiting for transaction...");
  const ev = await res.wait();
  console.log(`Transaction hash: ${ev?.transactionHash ?? null}`);
}

const prog = new Command();

prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

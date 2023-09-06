import { Command } from "commander";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import chains from "../../entities/chains";
import { LimitTradeHelper__factory } from "../../../../typechain";
import { MulticallWrapper } from "../../wrappers/MulticallWrapper";
import { ethers } from "ethers";
import { IMultiContractCall } from "../../wrappers/MulticallWrapper/interface";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const marketConfig = loadMarketConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;
  const multicallWrapper = new MulticallWrapper(config.multicall, provider);

  const limitTradeHelper = LimitTradeHelper__factory.connect(config.helpers.limitTrade, provider);

  const res = await multicallWrapper.multiContractCall<Array<ethers.BigNumber>>(
    marketConfig.markets.reduce((acc, market) => {
      acc.push({
        contract: limitTradeHelper,
        function: "positionSizeLimitOf",
        params: [market.index],
      });
      acc.push({
        contract: limitTradeHelper,
        function: "tradeSizeLimitOf",
        params: [market.index],
      });

      return acc;
    }, [] as Array<IMultiContractCall>)
  );

  console.table(
    marketConfig.markets.map((m, i) => {
      const offset = i * 2;
      return {
        market: m.name,
        tradeSizeLimit: ethers.utils.formatUnits(res[offset + 1], 30),
        positionSizeLimit: ethers.utils.formatUnits(res[offset], 30),
      };
    })
  );
}

const program = new Command();

program.requiredOption("--chain-id <number>", "chain id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

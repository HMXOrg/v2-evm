import { Command } from "commander";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import chains from "../../entities/chains";
import { LimitTradeHandler__factory, OrderReader__factory } from "../../../../typechain";
import { MulticallWrapper } from "../../wrappers/MulticallWrapper";
import { ethers } from "ethers";
import { IMultiContractCall } from "../../wrappers/MulticallWrapper/interface";
import { compareAddress } from "../../utils/address";
import axios from "axios";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;

  let timestamp = 1706004300;
  for (let i = 0; i < 60; i++) {
    timestamp = timestamp + i;
    const result = await axios.get(
      `https://hermes.pyth.network/api/get_price_feed?id=0xef2c98c804ba503c6a707e38be4dfbb16683775f195b091252bf24693042fd52&publish_time=${timestamp}`
    );
    console.log(result.data.price.price, result.data.price.publish_time);
  }

  const limitTradeHandler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, provider);
  const orders = await limitTradeHandler.getLimitActiveOrders(800, 800, { blockTag: 173320661 });
  const filteredOrder = orders.filter((each) => {
    return compareAddress(each.account, "0xD6Bab52DEC2561b6dBA8f4CA717A96bD0177b695");
  });
  console.log(
    filteredOrder.map((each) => {
      return {
        marketIndex: each.marketIndex.toString(),
        orderIndex: each.orderIndex.toString(),
        sizeDelta: each.sizeDelta.toString(),
      };
    })
  );
  // 0.0067619
  const orderReader = OrderReader__factory.connect("0x7C236EF2eCd133831a3E1ce8Da48E8FBe63E5CC3", provider);
  const result = await orderReader.getExecutableOrders(
    800,
    800,
    [
      225030633598, 4398058669722, 14462300000, 14789900000, 99984977, 18112704000, 14462300000, 204565900000,
      14524500000, 36764000000, 23747000000, 109397000, 2319300000, 116641562, 67131000, 127193000, 52856521, 83912297,
      87041002, 176692272, 329451747, 6570038875, 15402250000, 13722153000, 30696402380, 9590790788, 39673500000,
      57241714, 49082500000, 1368035053, 85012000, 8167500, 133610000, 132974000, 259193448852, 716294000, 781107000,
      23676342463, 2512122, 126669277, 112947323, 1025939000, 9877096493, 173841805, 153925224, 6875783404, 1465246163,
      3529745808, 3787627928, 728031666, 65337984, 999414233, 117550, 974880,
    ],
    [
      false,
      false,
      false,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ],
    { blockTag: 173320661 }
  );
  console.log(
    result
      .filter((each) => {
        return compareAddress(each.account, "0xD6Bab52DEC2561b6dBA8f4CA717A96bD0177b695");
      })
      .map((each) => {
        return {
          marketIndex: each.marketIndex.toString(),
          orderIndex: each.orderIndex.toString(),
          sizeDelta: each.sizeDelta.toString(),
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

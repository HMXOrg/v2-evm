import { Command } from "commander";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import chains from "../../entities/chains";
import { OrderReader__factory } from "../../../../typechain";
import { MulticallWrapper } from "../../wrappers/MulticallWrapper";
import { ethers } from "ethers";
import { IMultiContractCall } from "../../wrappers/MulticallWrapper/interface";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;

  const orderReader = OrderReader__factory.connect("0x9c0ee422bfe72f8c0c74c005a36ee5f80daba7b7", provider);
  const result = await orderReader.getExecutableOrders(
    800,
    800,
    [
      225030633598, 4398058669722, 99993559, 100059063, 99984977, 18112704000, 14462300000, 204565900000, 14524500000,
      36764000000, 23747000000, 109397000, 2319300000, 116641562, 67131000, 127193000, 52856521, 83912297, 87041002,
      176692272, 329451747, 6570038875, 15402250000, 13722153000, 30696402380, 9590790788, 39673500000, 57241714,
      49082500000, 1368035053, 85012000, 8167500, 133610000, 132974000, 259193448852, 716294000, 781107000, 23676342463,
      2512122, 126669277, 112947323, 1025939000, 9877096493, 173841805, 153925224, 6875783404, 1465246163, 3529745808,
      3787627928, 728031666, 65337984, 999414233, 117550, 974880,
    ],
    [
      false,
      false,
      false,
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
    ],
    { blockTag: 167730772, gasLimit: 120000000 }
  );
  console.log(result);
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

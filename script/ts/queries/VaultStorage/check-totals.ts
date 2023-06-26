import { ethers } from "ethers";
import chains from "../../entities/chains";
import { loadConfig } from "../../utils/config";
import collaterals from "../../entities/collaterals";
import MultiCall from "@indexed-finance/multicall";
import { VaultStorage__factory } from "../../../../typechain";
import { getSubAccount } from "../../utils/account";
import _ from "lodash";

async function main() {
  const accounts = [
    "0x480a54a3aa47f9351d9c0518b394c032f20a4713",
    "0x212c2a2891227f39b48d655c5eca0b1377daff90",
    "0xbf33c72b9b2dce5972af8067aa524bca7182a01f",
    "0x6629ec35c8aa279ba45dbfb575c728d3812ae31a",
    "0x0578c797798ae89b688cd5676348344d7d0ec35e",
    "0xa9a2da23f065a1483e701766cb8be761e855cee5",
    "0x2ac1d4ed5f6c0f20ffa29571910753e4cc941bb5",
    "0x66725488ff0977058b313022674c797fd3dd7134",
    "0x8ab428aa39e919705897f9d31d91f01c441c4813",
    "0x4ec989b6d17aebddab238eb2269067724f1e2883",
    "0x815612815d7fb01b1e8a97fe4a0996e77245a3aa",
    "0x8c5ee5afe1e3ce261e312fc0edc2a4b6f0f49338",
    "0xfd27c9fc2bb221dfb7de8de1858b336ff682c9e6",
    "0x6b20099a607a825a4eb5aeb3b5766434bc73552e",
    "0x3c8319dd83fa18ec1a0df2acf65277a731514d67",
    "0x9cef6e59c214179ef24e30ef50b3e6c15a37d4e4",
    "0xc40af2937ed35c6360c452335648e1b36329ad9d",
    "0xe0fb9b3a67cd620270aaadc759dc8922037a9174",
    "0x6ccc371476886b75a4787b3c01c619eed46a83a0",
    "0xbce338b553195f9ef224f7854e89d4aa75c8b83a",
    "0x04bee613690e98a1959f236c38abaa5f2439b14a",
    "0x10c69d9d8ae54fd1ab12a4bec82c2695b977bcec",
  ];
  const chain = chains[42161];
  const config = loadConfig(42161);
  const provider = new ethers.providers.JsonRpcProvider(chain.rpc);
  const multicall = new MultiCall(provider);

  const traderCollaterals: Record<string, ethers.BigNumber> = {};
  for (const [symbol, collateral] of Object.entries(collaterals)) {
    console.log(`Sum trader balances for ${symbol}`);
    let multicallCallData = [];
    // Check all trader's collateral
    for (const account of accounts) {
      for (let i = 0; i < 6; i++) {
        multicallCallData.push({
          target: config.storages.vault,
          function: "traderBalances",
          args: [getSubAccount(account, i), collateral.address],
        });
      }
    }
    // Chunk it to escape max code size exceeded
    const chunks = _.chunk(multicallCallData, 20);
    const promises = chunks.map((chunk) => multicall.multiCall(VaultStorage__factory.createInterface(), chunk));
    const results = await Promise.all(promises);
    const rawCollaterals = _.flatten(results.map((result) => result[1]));
    traderCollaterals[symbol] = rawCollaterals.reduce(
      (acc, rawCollateral) => acc.add(rawCollateral),
      ethers.BigNumber.from(0)
    );
    // Query HLP's liquidity, Protocol fees, and totalAmount
    multicallCallData = [];
    multicallCallData.push(
      ...[
        {
          target: config.storages.vault,
          function: "hlpLiquidity",
          args: [collateral.address],
        },
        {
          target: config.storages.vault,
          function: "protocolFees",
          args: [collateral.address],
        },
        {
          target: config.storages.vault,
          function: "totalAmount",
          args: [collateral.address],
        },
        { target: config.storages.vault, function: "devFees", args: [collateral.address] },
        { target: config.storages.vault, function: "fundingFeeReserve", args: [collateral.address] },
      ]
    );
    const [, [hlpLiquidity, protocolFees, totalAmount, devFees, fundingFeeReserve]] = await multicall.multiCall(
      VaultStorage__factory.createInterface(),
      multicallCallData
    );
    console.log(`hlpLiquidity: ${hlpLiquidity}`);
    console.log(`protocolFees: ${protocolFees}`);
    console.log(`devFees: ${devFees}`);
    console.log(
      `sum: ${traderCollaterals[symbol].add(hlpLiquidity).add(protocolFees).add(devFees).add(fundingFeeReserve)}`
    );
    console.log(`totalAmount: ${totalAmount}`);
    // console.table(traderCollaterals);
  }
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

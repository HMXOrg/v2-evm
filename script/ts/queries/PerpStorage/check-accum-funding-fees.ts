import { BigNumber, ethers } from "ethers";
import chains from "../../entities/chains";
import { loadConfig } from "../../utils/config";
import collaterals from "../../entities/collaterals";
import MultiCall from "@indexed-finance/multicall";
import { Calculator__factory, PerpStorage__factory, VaultStorage__factory } from "../../../../typechain";
import { getSubAccount } from "../../utils/account";

const ONE_ETHER = ethers.utils.parseEther("1");
const formatUnits = ethers.utils.formatUnits;

async function main() {
  const chain = chains[42161];
  const config = loadConfig(42161);
  const provider = new ethers.providers.JsonRpcProvider(chain.rpc);
  const multicall = new MultiCall(provider);

  const perpStorage = PerpStorage__factory.connect(config.storages.perp, provider);
  const activePositions = await perpStorage.getActivePositions(1000, 0);

  const numberOfMarkets = 24;
  const result = [];
  for (let i = 0; i < numberOfMarkets; i++) {
    const inputs = [
      {
        interface: PerpStorage__factory.abi,
        target: config.storages.perp,
        function: "markets",
        args: [i],
      },
      {
        interface: Calculator__factory.abi,
        target: config.calculator,
        function: "getFundingRateVelocity",
        args: [i],
      },
      {
        interface: Calculator__factory.abi,
        target: config.calculator,
        function: "proportionalElapsedInDay",
        args: [i],
      },
    ];
    const [, [market, fundingRateVelocity, proportionalElapsedInDay]] = await multicall.multiCall(inputs as any);
    const nextFundingRate = market.currentFundingRate.add(
      fundingRateVelocity.mul(proportionalElapsedInDay).div(ONE_ETHER)
    ); //int256 nextFundingRate = _market.currentFundingRate + ((_calculator.getFundingRateVelocity(_marketIndex) * proportionalElapsedInDay) / 1e18);
    const lastFundingAccrued = market.fundingAccrued;
    const newFundingAccrued = lastFundingAccrued.add(
      market.currentFundingRate.add(nextFundingRate).mul(proportionalElapsedInDay).div(2).div(ONE_ETHER)
    );

    const accumFundingLong = market.accumFundingLong.add(
      getFundingFee(market.longPositionSize, newFundingAccrued, lastFundingAccrued)
    );
    const accumFundingShort = market.accumFundingShort.add(
      getFundingFee(market.shortPositionSize.mul(-1), newFundingAccrued, lastFundingAccrued)
    );
    const positions = activePositions.filter((each: any) => each.marketIndex.eq(i));
    let allFundingFee = BigNumber.from(0);
    positions.forEach((each: any) => {
      const fundingFee = getFundingFee(each.positionSizeE30, newFundingAccrued, each.lastFundingAccrued);
      allFundingFee = allFundingFee.add(fundingFee);
    });

    result.push({
      market: i,
      accumFundingLong: formatUnits(accumFundingLong, 30),
      accumFundingShort: formatUnits(accumFundingShort, 30),
      sumFundingFeeAllPositions: formatUnits(allFundingFee, 30),
      diff: formatUnits(accumFundingLong.add(accumFundingShort).sub(allFundingFee), 30),
    });
  }
  console.table(result);

  const inputs = [
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "fundingFeeReserve",
      args: [config.tokens.weth],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "fundingFeeReserve",
      args: [config.tokens.wbtc],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "fundingFeeReserve",
      args: [config.tokens.usdc],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "fundingFeeReserve",
      args: [config.tokens.usdt],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "fundingFeeReserve",
      args: [config.tokens.dai],
    },
    {
      interface: VaultStorage__factory.abi,
      target: config.storages.vault,
      function: "fundingFeeReserve",
      args: [config.tokens.sglp],
    },
  ];
  const [
    ,
    [
      wethFundingFeeReserve,
      wbtcFundingFeeReserve,
      usdcFundingFeeReserve,
      usdtFundingFeeReserve,
      daiFundingFeeReserve,
      sglpFundingFeeReserve,
    ],
  ] = await multicall.multiCall(inputs as any);
  console.table({
    wethFundingFeeReserve: formatUnits(wethFundingFeeReserve, 18),
    wbtcFundingFeeReserve: formatUnits(wbtcFundingFeeReserve, 8),
    usdcFundingFeeReserve: formatUnits(usdcFundingFeeReserve, 6),
    usdtFundingFeeReserve: formatUnits(usdtFundingFeeReserve, 6),
    daiFundingFeeReserve: formatUnits(daiFundingFeeReserve, 18),
    sglpFundingFeeReserve: formatUnits(sglpFundingFeeReserve, 18),
  });
}

function getFundingFee(size: BigNumber, currentFundingAccrued: BigNumber, lastFundingAccrued: BigNumber): BigNumber {
  const fundingAccrued = currentFundingAccrued.sub(lastFundingAccrued);
  return size.mul(fundingAccrued).div(ONE_ETHER);
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

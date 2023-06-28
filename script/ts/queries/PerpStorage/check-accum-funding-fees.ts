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
  const activePositions = await perpStorage.getActivePositions(100, 0);

  const numberOfMarkets = 15;
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
    const [, [market_eth, fundingRateVelocity, proportionalElapsedInDay]] = await multicall.multiCall(inputs as any);
    const nextFundingRate = market_eth.currentFundingRate.add(
      fundingRateVelocity.mul(proportionalElapsedInDay).div(ONE_ETHER)
    ); //int256 nextFundingRate = _market.currentFundingRate + ((_calculator.getFundingRateVelocity(_marketIndex) * proportionalElapsedInDay) / 1e18);
    const lastFundingAccrued = market_eth.fundingAccrued;
    const newFundingAccrued = lastFundingAccrued.add(
      market_eth.currentFundingRate.add(nextFundingRate).mul(proportionalElapsedInDay).div(2).div(ONE_ETHER)
    );

    const accumFundingLong = market_eth.accumFundingLong.add(
      getFundingFee(market_eth.longPositionSize, newFundingAccrued, lastFundingAccrued)
    );
    const accumFundingShort = market_eth.accumFundingShort.add(
      getFundingFee(market_eth.shortPositionSize.mul(-1), newFundingAccrued, lastFundingAccrued)
    );
    console.log("market", i);
    console.log("accumFundingLong", formatUnits(accumFundingLong, 30));
    console.log("accumFundingShort", formatUnits(accumFundingShort, 30));

    const positions = activePositions.filter((each: any) => each.marketIndex.eq(i));
    let allFundingFee = BigNumber.from(0);
    positions.forEach((each: any) => {
      const fundingFee = getFundingFee(each.positionSizeE30, newFundingAccrued, each.lastFundingAccrued);
      allFundingFee = allFundingFee.add(fundingFee);
    });
    console.log("sumFundingFeeAllPositions", formatUnits(allFundingFee, 30));
    console.log("diff", formatUnits(accumFundingLong.add(accumFundingShort).sub(allFundingFee), 30));
  }
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

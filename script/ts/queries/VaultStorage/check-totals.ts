import { ethers } from "ethers";
import chains from "../../entities/chains";
import { loadConfig } from "../../utils/config";
import collaterals from "../../entities/collaterals";
import { VaultStorage__factory } from "../../../../typechain";
import { getSubAccount } from "../../utils/account";
import _ from "lodash";
import { Command } from "commander";
import { MulticallWrapper } from "../../wrappers/MulticallWrapper";
import { IMultiContractCall } from "../../wrappers/MulticallWrapper/interface";
import { readCsv } from "../../utils/file";

type CheckTotalTable = {
  collateralSymbol: string;
  traderCollateral: string;
  hlpLiquidity: string;
  protocolFees: string;
  devFees: string;
  fundingFeeReserve: string;
  sum: string;
  totalAmount: string;
  diff: string;
};

type AccountRow = {
  primaryAccount: string;
};

async function main(chainId: number, accountPath: string, blockNumber?: number) {
  const accountRows: Array<AccountRow> = await readCsv(accountPath);
  accountRows.push({ primaryAccount: "0x3231C08B500bb26e0654cb0338F135CeD44d6B84" }); // liquidator

  const chain = chains[chainId];
  const config = loadConfig(chainId);
  const provider = new ethers.providers.JsonRpcProvider(chain.rpc);
  const multicall = new MulticallWrapper(config.multicall, provider);
  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, provider);
  const displayTable: CheckTotalTable[] = [];
  blockNumber = blockNumber || (await provider.getBlockNumber());

  const traderCollaterals: Record<string, ethers.BigNumber> = {};
  for (const [symbol, collateral] of Object.entries(collaterals)) {
    console.log(`Sum trader balances for ${symbol}`);
    let multicallCallData: Array<IMultiContractCall> = [];
    // Check all trader's collateral
    for (const row of accountRows) {
      for (let i = 0; i < 6; i++) {
        multicallCallData.push({
          contract: vaultStorage,
          function: "traderBalances",
          params: [getSubAccount(row.primaryAccount, i), collateral.address],
        });
      }
    }
    // Chunk it to escape max code size exceeded
    const chunks = _.chunk(multicallCallData, 20);
    const promises = chunks.map((chunk) =>
      multicall.multiContractCall<Array<ethers.BigNumber>>(chunk, { blockNumber })
    );
    const results = await Promise.all(promises);
    const rawCollaterals = _.flatten(results);
    traderCollaterals[symbol] = rawCollaterals.reduce(
      (acc, rawCollateral) => acc.add(rawCollateral),
      ethers.BigNumber.from(0)
    );
    // Query HLP's liquidity, Protocol fees, and totalAmount
    multicallCallData = [];
    multicallCallData.push(
      ...[
        {
          contract: vaultStorage,
          function: "hlpLiquidity",
          params: [collateral.address],
        },
        {
          contract: vaultStorage,
          function: "protocolFees",
          params: [collateral.address],
        },
        {
          contract: vaultStorage,
          function: "totalAmount",
          params: [collateral.address],
        },
        { contract: vaultStorage, function: "devFees", params: [collateral.address] },
        { contract: vaultStorage, function: "fundingFeeReserve", params: [collateral.address] },
      ]
    );
    const [hlpLiquidity, protocolFees, totalAmount, devFees, fundingFeeReserve] = await multicall.multiContractCall<
      Array<ethers.BigNumber>
    >(multicallCallData, { blockNumber });
    const sum = traderCollaterals[symbol].add(hlpLiquidity).add(protocolFees).add(devFees).add(fundingFeeReserve);
    displayTable.push({
      collateralSymbol: symbol,
      traderCollateral: ethers.utils.formatUnits(traderCollaterals[symbol], collateral.decimals),
      hlpLiquidity: ethers.utils.formatUnits(hlpLiquidity, collateral.decimals),
      protocolFees: ethers.utils.formatUnits(protocolFees, collateral.decimals),
      devFees: ethers.utils.formatUnits(devFees, collateral.decimals),
      fundingFeeReserve: ethers.utils.formatUnits(fundingFeeReserve, collateral.decimals),
      sum: ethers.utils.formatUnits(sum, collateral.decimals),
      totalAmount: ethers.utils.formatUnits(totalAmount, collateral.decimals),
      diff: ethers.utils.formatUnits(totalAmount.sub(sum), collateral.decimals),
    });
  }
  const block = blockNumber;
  console.log(`Block: ${block}`);
  console.table(displayTable);
}

const program = new Command();

program.requiredOption("--chain-id <number>", "chain id", parseInt);
program.requiredOption("--account-path <path>", "account path");
program.option("--block-number <number>", "block number", parseInt);

const options = program.parse(process.argv).opts();

main(options.chainId, options.accountPath, options.blockNumber)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

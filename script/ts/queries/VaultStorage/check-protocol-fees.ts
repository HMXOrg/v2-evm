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

  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, provider);
  const protocolFees = {
    weth: formatUnits(await vaultStorage.protocolFees(config.tokens.weth), 18),
    wbtc: formatUnits(await vaultStorage.protocolFees(config.tokens.wbtc), 8),
    usdt: formatUnits(await vaultStorage.protocolFees(config.tokens.usdt), 6),
    usdc: formatUnits(await vaultStorage.protocolFees(config.tokens.usdc), 6),
    dai: formatUnits(await vaultStorage.protocolFees(config.tokens.dai), 18),
    glp: formatUnits(await vaultStorage.protocolFees(config.tokens.sglp), 18),
  };
  console.table(protocolFees);
  const devFees = {
    weth: formatUnits(await vaultStorage.devFees(config.tokens.weth), 18),
    wbtc: formatUnits(await vaultStorage.devFees(config.tokens.wbtc), 8),
    usdt: formatUnits(await vaultStorage.devFees(config.tokens.usdt), 6),
    usdc: formatUnits(await vaultStorage.devFees(config.tokens.usdc), 6),
    dai: formatUnits(await vaultStorage.devFees(config.tokens.dai), 18),
    glp: formatUnits(await vaultStorage.devFees(config.tokens.sglp), 18),
  };
  console.table(devFees);
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

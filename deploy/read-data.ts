import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { Calculator__factory, OracleMiddleware__factory, VaultStorage__factory, ERC20__factory, PLPv2__factory } from "../typechain";
import { getConfig } from "./utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();
const subAccountId = 0;

const ethAssetId = "0x0000000000000000000000000000000000000000000000000000000000000001";
const wbtcAssetId = "0x0000000000000000000000000000000000000000000000000000000000000002";
const usdcAssetId = "0x0000000000000000000000000000000000000000000000000000000000000003";
const usdtAssetId = "0x0000000000000000000000000000000000000000000000000000000000000004";
const daiAssetId = "0x0000000000000000000000000000000000000000000000000000000000000005";
const appleAssetId = "0x0000000000000000000000000000000000000000000000000000000000000006";
const jpyAssetId = "0x0000000000000000000000000000000000000000000000000000000000000007";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const deployer = (await ethers.getSigners())[0];
  const address = BigNumber.from(deployer.address).xor(subAccountId).toHexString()

  const usdc = ERC20__factory.connect(config.tokens.usdc, deployer)
  const usdcBalance = await usdc.balanceOf(deployer.address)
  console.log('usdc balance', ethers.utils.formatUnits(usdcBalance, 6));

  const usdt = ERC20__factory.connect(config.tokens.usdt, deployer)
  const usdtBalance = await usdt.balanceOf(deployer.address)
  console.log('usdt balance', ethers.utils.formatUnits(usdtBalance, 6));

  const wbtc = ERC20__factory.connect(config.tokens.wbtc, deployer)
  const wbtcBalance = await wbtc.balanceOf(deployer.address)
  console.log('wbtc balance', ethers.utils.formatUnits(wbtcBalance, 8));

  const dai = ERC20__factory.connect(config.tokens.dai, deployer)
  const daiBalance = await dai.balanceOf(deployer.address)
  console.log('dai balance', ethers.utils.formatUnits(daiBalance, 18));

  const provider = ethers.provider;
  console.log('eth balance', ethers.utils.formatUnits(await provider.getBalance(deployer.address), 18));


  const vaultStorage = VaultStorage__factory.connect(config.storages.vault, deployer);
  const calculator = Calculator__factory.connect(config.calculator, deployer);
  const oracle = OracleMiddleware__factory.connect(config.oracle.middleware, deployer)
  const plp = PLPv2__factory.connect(config.tokens.plp, deployer)

  const traderBalancesUsdc = await vaultStorage.traderBalances(address, config.tokens.usdc)
  const traderBalancesUsdt = await vaultStorage.traderBalances(address, config.tokens.usdt)
  const traderBalancesWbtc = await vaultStorage.traderBalances(address, config.tokens.wbtc)
  const traderBalancesEth = await vaultStorage.traderBalances(address, config.tokens.weth)
  const traderBalancesDai = await vaultStorage.traderBalances(address, config.tokens.dai)



  const freeCollateral = await calculator.getFreeCollateral(address, 0, "0x0000000000000000000000000000000000000000000000000000000000000000")
  const equity = await calculator.getEquity(address, 0, "0x0000000000000000000000000000000000000000000000000000000000000000")
  const usdcPrice = (await oracle.getLatestPrice(usdcAssetId, false))._price;
  const usdtPrice = (await oracle.getLatestPrice(usdtAssetId, false))._price;
  const wbtcPrice = (await oracle.getLatestPrice(wbtcAssetId, false))._price;
  const daiPrice = (await oracle.getLatestPrice(daiAssetId, false))._price;
  const ethPrice = (await oracle.getLatestPrice(ethAssetId, false))._price;
  const plpBalance = await plp.balanceOf(deployer.address)

  console.log("USDCPrice", ethers.utils.formatUnits(usdcPrice, 30));
  console.log("USDTPrice", ethers.utils.formatUnits(usdtPrice, 30));
  console.log("WBTCPrice", ethers.utils.formatUnits(wbtcPrice, 30));
  console.log("DAIPrice", ethers.utils.formatUnits(daiPrice, 30));
  console.log("ETHPrice", ethers.utils.formatUnits(ethPrice, 30));
  console.log("=====================");
  console.log("traderBalancesUSDC", ethers.utils.formatUnits(traderBalancesUsdc, 6));
  console.log("traderBalancesUSDT", ethers.utils.formatUnits(traderBalancesUsdt, 6));
  console.log("traderBalancesWBTC", ethers.utils.formatUnits(traderBalancesWbtc, 8));
  console.log("traderBalancesETH", ethers.utils.formatUnits(traderBalancesEth, 18));
  console.log("traderBalancesDAI", ethers.utils.formatUnits(traderBalancesDai, 18));
  console.log("=====================");
  console.log("equity", ethers.utils.formatUnits(equity, 30));
  console.log("freeCollateral", ethers.utils.formatUnits(freeCollateral, 30));
  console.log("=====================");
  console.log("plpBalance", ethers.utils.formatUnits(plpBalance, 18));
  console.log("plpTotalSupply", ethers.utils.formatUnits(await plp.totalSupply(), 18));
  console.log("plpLiquidity USDC", ethers.utils.formatUnits(await vaultStorage.plpLiquidity(config.tokens.usdc), 6));
  console.log("plpLiquidity USDT", ethers.utils.formatUnits(await vaultStorage.plpLiquidity(config.tokens.usdt), 6));
  console.log("plpLiquidity WBTC", ethers.utils.formatUnits(await vaultStorage.plpLiquidity(config.tokens.wbtc), 8));
  console.log("plpLiquidity ETH", ethers.utils.formatUnits(await vaultStorage.plpLiquidity(config.tokens.weth), 18));
  console.log("=========platform fee============");
  console.log("fees USDC", ethers.utils.formatUnits(await vaultStorage.fees(config.tokens.usdc), 6));
  console.log("fees USDT", ethers.utils.formatUnits(await vaultStorage.fees(config.tokens.usdt), 6));
  console.log("fees WBTC", ethers.utils.formatUnits(await vaultStorage.fees(config.tokens.wbtc), 8));
  console.log("fees ETH", ethers.utils.formatUnits(await vaultStorage.fees(config.tokens.weth), 18));
};

export default func;
func.tags = ["ReadData"];

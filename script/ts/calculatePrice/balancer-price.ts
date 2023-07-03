import { BigNumber, ethers } from "ethers";
import chains from "../entities/chains";
import { loadConfig } from "../utils/config";

const POOL_ABI = require('./pool_abi.json')
const VAULT_ABI = require('./vault_abi.json')
const ERC20_ABI = [
    // Read-Only Functions
    "function balanceOf(address owner) view returns (uint256)",
    "function decimals() view returns (uint8)",
    "function symbol() view returns (string)",
    // Authenticated Functions
    "function transfer(address to, uint amount) returns (bool)",
    // Events
    "event Transfer(address indexed from, address indexed to, uint amount)"
];

const ADDRESS = "0xFd29298041eA355cF7e15652689F2865443C3144";

const chain = chains[42161];
const config = loadConfig(42161);
const provider = new ethers.providers.JsonRpcProvider(chain.rpc);

const IN = 1;
const OUT = 0;

const ONE_ETHER = ethers.utils.parseEther("1");

async function main() {
    const pool_contract = new ethers.Contract(ADDRESS, POOL_ABI, provider);
    pool_contract.connect(provider);

    const normalizedWeights: any = await pool_contract.getNormalizedWeights(); // BigNumber
    const swapFee = (await pool_contract.getSwapFeePercentage()) / 1e+18;     // Number, div by rate(decimals)
    const poolId = await pool_contract.getPoolId();
    const VAULT_ADDRESS = await pool_contract.getVault();

    // Vault Contract to get pool's tokens
    const vault_contract = new ethers.Contract(VAULT_ADDRESS,VAULT_ABI, provider);

    // Get ERC20 Token's Contracts, to call `decimals()` to calculate the rate
    const tokens_data = await vault_contract.getPoolTokens(poolId);
    const tokenIn = tokens_data['tokens'][IN];
    const tokenOut = tokens_data['tokens'][OUT];
    const contract_tokenIn = new ethers.Contract(tokenIn, ERC20_ABI, provider);
    const contract_tokenOut = new ethers.Contract(tokenOut, ERC20_ABI, provider);
    const decimalIn = await contract_tokenIn.decimals();
    const decimalOut = await contract_tokenOut.decimals();
    const tokenSymbolIn = await contract_tokenIn.symbol();
    const tokenSymbolOut = await contract_tokenOut.symbol();
    console.log('Decimals of '+tokenSymbolIn+':', decimalIn);
    console.log('Decimals of '+tokenSymbolOut+':', decimalOut);

    // // Set rate for div
    const rateIn: BigNumber = decimalIn == 18 ? ONE_ETHER : BigNumber.from(10 ** decimalIn);
    const rateOut: BigNumber = decimalOut == 18 ? ONE_ETHER : BigNumber.from(10 ** decimalOut);
    const rateW: BigNumber = BigNumber.from(ONE_ETHER);

    // Calculate vars for the equation
    const weightIn = normalizedWeights[IN]
    const weightOut = normalizedWeights[OUT]
    const minimizedWeightIn = weightIn.mul(BigNumber.from(10)).div(rateW).toNumber() // div by decimal = 1e18, mul 10 cause BigNumber got rounded
    const minimizedWeightOut = weightOut.mul(BigNumber.from(10)).div(rateW).toNumber() // div by decimal = 1e18, mul 10 cause BigNumber got rounded
    // console.log('#### Var Info ####');
    // console.log('Wi:', minimizedWeightIn);
    // console.log('Wo:', minimizedWeightOut);
    // console.log('SwapFee:', swapFee);

    // Get the pool's balance of each token
    // console.log('#### Balance Info ####');
    // console.log('BI:', tokens_data['balances'][IN]);
    // console.log('BO:', tokens_data['balances'][OUT]);
    const balancesIn = tokens_data['balances'][IN].div(rateIn).toNumber();
    const balancesOut = tokens_data['balances'][OUT].div(rateOut).toNumber();
    
    // Calculate SP: Spot Price
    const price = ((balancesIn / minimizedWeightIn) / (balancesOut / minimizedWeightOut)) * (1 / (1 - swapFee));
    console.log('SpotPrice of '+tokenSymbolOut+'/'+tokenSymbolIn+':', price);
}

main();
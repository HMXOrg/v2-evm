type CollateralEntity = {
  address: string;
  decimals: number;
};

export default {
  "USDC.e": {
    address: "0xff970a61a04b1ca14834a43f5de4533ebddb5cc8",
    decimals: 6,
  },
  USDT: {
    address: "0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9",
    decimals: 6,
  },
  DAI: {
    address: "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1",
    decimals: 18,
  },
  WETH: {
    address: "0x82af49447d8a07e3bd95bd0d56f35241523fbab1",
    decimals: 18,
  },
  WBTC: {
    address: "0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f",
    decimals: 8,
  },
  sGLP: {
    address: "0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf",
    decimals: 18,
  },
} as { [collateralSymbol: string]: CollateralEntity };

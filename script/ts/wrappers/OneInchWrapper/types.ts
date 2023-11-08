export type OneInchToken = {
  symbol: string;
  name: string;
  decimals: string;
  address: string;
  logoURI: string;
};

export type OneInchHop = {
  name: string;
  part: number;
  fromTokenAddress: string;
  toTokenAddress: string;
};

export type OneInchTx = {
  from: string;
  to: string;
  data: string;
  value: string;
  gasPrice: string;
  gas: number;
};

export type OneInchSwap = {
  toAmount: string;
  tx: OneInchTx;
};

export type OneInchSpender = {
  address: string;
};

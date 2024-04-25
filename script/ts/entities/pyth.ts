import { ethers } from "ethers";

export type PythEvmPriceStruct = {
  expo: number;
  price: ethers.BigNumber;
};

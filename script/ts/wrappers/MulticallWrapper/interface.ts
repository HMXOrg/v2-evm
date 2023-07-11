import { Contract } from "ethers";

export interface IMultiContractCall {
  contract: Contract;
  function: string;
  params?: any[];
}

export interface ContractCallOptions {
  blockNumber?: number;
}

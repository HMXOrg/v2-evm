import { ethers } from "ethers";
import { ContractCallOptions, IMultiContractCall } from "./interface";
import { abi as multicall3Abi } from "./Multicall3.json";

export class MulticallWrapper {
  private multicallInstance: ethers.Contract;

  constructor(_multicallAddress: string, _signerOrProvider: ethers.Signer | ethers.providers.Provider) {
    this.multicallInstance = new ethers.Contract(_multicallAddress, multicall3Abi, _signerOrProvider);
  }

  public async multiContractCall<T>(
    calls: IMultiContractCall[],
    contractCallOptions?: ContractCallOptions
  ): Promise<T> {
    let blockNumber = undefined;
    if (contractCallOptions) blockNumber = contractCallOptions.blockNumber;

    return this._multiCall(calls, blockNumber);
  }

  private async _multiCall<T>(calls: IMultiContractCall[], blockNumber?: number): Promise<T> {
    try {
      const calldata = calls.map((call) => {
        return {
          target: call.contract.address.toLowerCase(),
          callData: call.contract.interface.encodeFunctionData(call.function, call.params),
        };
      });

      const { returnData } = (await this.multicallInstance.callStatic.aggregate(calldata, {
        blockTag: blockNumber,
      })) as { blockNumber: ethers.BigNumber; returnData: string[] };

      const res = returnData.map((call, i) => {
        const result = calls[i].contract.interface.decodeFunctionResult(calls[i].function, call);
        if (result.length === 1) return result[0];
        return result;
      });

      return res as unknown as T;
    } catch (error) {
      throw new Error(error as string);
    }
  }
}

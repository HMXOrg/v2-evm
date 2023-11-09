import axios from "axios";
import { OneInchSwap } from "./types";

export class OneInchWrapper {
  private chainId: number;
  private oneInchApiUrl: string;
  private oneInchApiKey: string;

  constructor(chainId: number, oneInchApiUrl: string, oneInchApiKey: string) {
    this.chainId = chainId;
    this.oneInchApiUrl = oneInchApiUrl;
    this.oneInchApiKey = oneInchApiKey;
  }

  async getSwapData(user: string, fromTokenAddress: string, toTokenAddress: string, amount: string, slippage: number) {
    const oneInchData = (
      await axios.get(`${this.oneInchApiUrl}/swap/v5.2/${this.chainId}/swap`, {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.oneInchApiKey}`,
        },
        params: {
          src: fromTokenAddress,
          dst: toTokenAddress,
          amount: amount.toString(),
          from: user,
          slippage: slippage.toString(),
          disableEstimate: "true",
        },
      })
    ).data as OneInchSwap;

    return oneInchData;
  }
}

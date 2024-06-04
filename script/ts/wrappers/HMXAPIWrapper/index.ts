import axios from "axios";
import { Agent } from "node:https";

export default class {
  chainId: number;
  baseUrl: string;
  chainName: string;

  constructor(chainId: number) {
    this.chainId = chainId;
    if (this.chainId === 42161 || this.chainId === 81457) {
      this.baseUrl = `${process.env.HMX_API_PROD_ENDPOINT}`;
    } else {
      this.baseUrl = `${process.env.HMX_API_DEV_ENDPOINT}`;
    }

    if (this.chainId === 42161 || this.chainId === 421614) {
      this.chainName = "arbitrum";
    } else {
      this.chainName = "blast";
    }
  }

  async refreshAssetIds() {
    const endpoint = `${this.baseUrl}/${this.chainName}/v1/internal/pyth/asset-ids.reload`;
    try {
      await axios.post(endpoint);
    } catch (e: any) {
      const statusCode = e.response.data.status.code;
      if (statusCode === 8900) {
        console.log("lastest asset id cache is equal to the contract");
      }
    }
  }

  async feedOrderbookOracle() {
    const endpoint = `${this.baseUrl}/${this.chainName}/v1/internal/adaptive-fee.updateContract`;
    await axios.post(endpoint, {
      force: true,
    });
  }

  async refreshMarketIds() {
    const endpoint = `${this.baseUrl}/${this.chainName}/v1/internal/market-ids.reload`;
    try {
      await axios.post(endpoint);
    } catch (e: any) {
      console.log(e);
      const statusCode = e.response.data.status.code;
      if (statusCode === 8900) {
        console.log("lastest market id cache is equal to the contract");
      }
    }
  }

  async syncAdaptiveFeeDatabase() {
    const endpoint = `${this.baseUrl}/${this.chainName}/v1/internal/adaptive-fee.updateDB`;
    await axios.post(endpoint, {
      force: true,
    });
  }
}

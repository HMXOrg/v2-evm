import axios from "axios";

export default class {
  chainId: number;
  baseUrl: string;

  constructor(chainId: number) {
    this.chainId = chainId;
    this.baseUrl =
      this.chainId === 42161 ? `${process.env.HMX_API_PROD_ENDPOINT}` : `${process.env.HMX_API_DEV_ENDPOINT}`;
  }

  async refreshAssetIds() {
    const endpoint = `${this.baseUrl}/arbitrum/v1/internal/pyth/asset-ids.reload`;
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
    const endpoint = `${this.baseUrl}/arbitrum/v1/internal/adaptive-fee.update`;
    await axios.post(endpoint, {
      force: true,
    });
  }
}

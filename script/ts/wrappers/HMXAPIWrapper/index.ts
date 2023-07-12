import axios from "axios";

export default class {
  chainId: number;

  constructor(chainId: number) {
    this.chainId = chainId;
  }

  async refreshAssetIds() {
    const endpoint =
      this.chainId === 42161
        ? `${process.env.HMX_API_PROD_ENDPOINT}/arbitrum/v1/internal/pyth/asset-ids.reload`
        : `${process.env.HMX_API_DEV_ENDPOINT}/arbitrum/v1/internal/pyth/asset-ids.reload`;
    try {
      await axios.post(endpoint);
    } catch (e: any) {
      const statusCode = e.response.data.status.code;
      if (statusCode === 8900) {
        console.log("lastest asset id cache is equal to the contract");
      }
    }
  }
}

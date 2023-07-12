import axios from "axios";

export async function refreshAssetIds(chaindId: number) {
  if (chaindId === 421613) {
    try {
      await axios.post("https://dev-api.perp88.com/api/hmx-v2/arbitrum/v1/internal/pyth/asset-ids.reload");
    } catch (e: any) {
      const statusCode = e.response.data.status.code;
      if (statusCode === 8900) {
        console.log("lastest asset id cache is equal to the contract");
      }
    }
  } else if (chaindId === 42161) {
    await axios.post("https://api.perp88.com/api/hmx-v2/arbitrum/v1/internal/pyth/asset-ids.reload");
  }
}

import { ethers } from "ethers";

type CollateralEntity = {
  assetId: string;
  address: string;
  decimals: number;
};

export default {
  ybETH2: {
    assetId: ethers.utils.formatBytes32String("ybETH"),
    address: "0xb9d94A3490bA2482E2D4F21F0E76b92E5661Ded8",
    decimals: 18,
  },
  ybUSDB2: {
    assetId: ethers.utils.formatBytes32String("ybUSDB"),
    address: "0xCD732d21c1B23A3f84Bb386E9759b5b6A1BcBe39",
    decimals: 18,
  },
} as { [collateralSymbol: string]: CollateralEntity };

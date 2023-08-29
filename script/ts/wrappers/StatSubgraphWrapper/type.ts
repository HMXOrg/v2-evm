import { ethers } from "ethers";

export type SubAccountStat = {
  primaryAccount: string;
  subAccountId: string;
  subAccount: string;
  tradingFeePaid: ethers.BigNumberish;
  borrowingFeePaid: ethers.BigNumberish;
  liquidationFeePaid: ethers.BigNumberish;
  fundingFeePaid: ethers.BigNumberish;
  fundingFeeReceived: ethers.BigNumberish;
  totalFeesPaid: ethers.BigNumberish;
  totalFeesReceived: ethers.BigNumberish;
  accumulatedPnl: ethers.BigNumberish;
};

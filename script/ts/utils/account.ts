import { ethers } from "ethers";

export function getSubAccount(primaryAccount: string, subAccountId: number): string {
  return ethers.utils.hexZeroPad(ethers.BigNumber.from(primaryAccount).xor(subAccountId).toHexString(), 20);
}

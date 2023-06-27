import { ethers } from "ethers";

export function getSubAccount(primaryAccount: string, subAccountId: number): string {
  return ethers.BigNumber.from(primaryAccount).xor(subAccountId).toHexString();
}

import { Command } from "commander";
import { getSubAccount } from "../../utils/account";

function main(primaryAccount: string, subAccountId: number) {
  console.log("Primary Account: ", primaryAccount);
  console.log("Sub Account Id: ", subAccountId);
  console.log("Sub Account: ", getSubAccount(primaryAccount, subAccountId));
}

const program = new Command();

program
  .requiredOption("--primary-account <primaryAccount>", "Primary Account")
  .requiredOption("--sub-account-id <subAccountId>", "Sub Account Id", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.primaryAccount, opts.subAccountId);

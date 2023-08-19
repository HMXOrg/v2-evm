import { Command } from "commander";

async function main(chainId: number) {}

const program = new Command();

program.requiredOption("-c, --chainId <chainId>", "chainId", parseInt);

const opts = program.parse(process.argv).opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });

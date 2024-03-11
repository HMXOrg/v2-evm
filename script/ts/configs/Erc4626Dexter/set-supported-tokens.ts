import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Erc4626Dexter__factory } from "../../../../typechain";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const SUPPORTED_TOKENS = [
    {
      erc4626Address: config.tokens.ybeth!,
      isSupported: true,
    },
    {
      erc4626Address: config.tokens.ybeth2!,
      isSupported: true,
    },
    {
      erc4626Address: config.tokens.ybusdb!,
      isSupported: true,
    },
    {
      erc4626Address: config.tokens.ybusdb2!,
      isSupported: true,
    },
  ];

  const deployer = signers.deployer(chainId);
  const dexter = Erc4626Dexter__factory.connect(config.extension.dexter.erc4626!, deployer);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  console.log("[Erc4626Dexter] Setting supported tokens...");
  for (const st of SUPPORTED_TOKENS) {
    await ownerWrapper.authExec(
      dexter.address,
      dexter.interface.encodeFunctionData("setSupportedToken", [st.erc4626Address, st.isSupported])
    );
  }
}

const prog = new Command();
prog.requiredOption("--chain-id <chainId>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });

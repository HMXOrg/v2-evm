import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { IYBToken__factory } from "../../../../typechain";
import { ethers } from "ethers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = signers.deployer(chainId);
  const signerAddress = await signer.getAddress();

  console.log("[ybETH] Deposit ETH...");
  const ybETH = IYBToken__factory.connect("0x1BE63A4D24a8AaffaB26745Bde8be0B6887241C8", signer);
  const tx = await ybETH.depositETH(signerAddress, {
    value: ethers.utils.parseEther("0.01"),
    gasLimit: 10000000,
  });
  console.log(`[ybETH] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[ybETH] Finished");
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

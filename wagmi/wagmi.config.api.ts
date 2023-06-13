import { defineConfig } from "@wagmi/cli";
import { foundry, actions } from "@wagmi/cli/plugins";
import inclusion from "./inclusion.api";

export default defineConfig({
  out: "wagmi/generated.api.ts",
  contracts: [],
  plugins: [
    foundry({
      include: inclusion,
    }),
    actions({ overridePackageName: "@wagmi/core", prepareWriteContract: false, writeContract: false }),
  ],
});

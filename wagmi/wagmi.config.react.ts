import { defineConfig } from "@wagmi/cli";
import { foundry, react } from "@wagmi/cli/plugins";
import inclusion from "./inclusion.react";

export default defineConfig({
  out: "wagmi/generated.react.ts",
  contracts: [],
  plugins: [
    foundry({
      include: inclusion,
    }),
  ],
});

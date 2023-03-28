import { defineConfig } from "@wagmi/cli";
import { foundry, actions } from "@wagmi/cli/plugins";
import inclusion from "./inclusion";

export default defineConfig({
  out: "wagmi/generated.api.ts",
  contracts: [],
  plugins: [
    foundry({
      include: inclusion,
    }),
    actions(),
  ],
});

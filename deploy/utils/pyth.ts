import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";

export async function getPriceData(priceIds: string[]): Promise<string[]> {
  // https://xc-mainnet.pyth.network
  // https://xc-testnet.pyth.network
  const connection = new EvmPriceServiceConnection("https://xc-testnet.pyth.network", {
    logger: console, // Providing logger will allow the connection to log its events.
  });

  return connection.getPriceFeedsUpdateData(priceIds);
}

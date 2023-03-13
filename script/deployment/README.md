## Deployment sequence

1. Deploy pyth adapter
2. Deploy oracle middleware
3. Deploy storages & PLPv2
  - Config storage
  - Perp storage
  - Vault storage
  - PLPv2
4. Deploy calculators
  - Calculator
  - Fee Calcualtor
5. Set calculator in ConfigStorage
6. Deploy services
  - Cross margin service
  - Liquidation service
  - Liquidity service
  - Trade service
7. Deploy handlers
  - Bot handler
  - Cross margin handler
  - Liquidity handler
  - Market trade handler
  - Limit trade handler
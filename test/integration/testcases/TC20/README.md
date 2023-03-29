## TC20 - Trade with max utilization

### Scenario: Prepare environment
Given Max Utilization is 80%
And BTC price is 20,000 USD
And WETH price is 1,500 USD
And APPLE price is 152 USD
And Bob provide liquidity 5 btc
And Alice deposit 5 btc as Collateral
And Bob deposit 0.5 btc as Collateral

### Scenario: Traders trade normally
When Alice sell WETH 600,000 USD
Then Alice's WETH position should be corrected
When Bob buy APPLE 100,000 USD
Then Revert InsufficientLiquidity
When Bob buy APPLE 20,000 USD
Then Bob's APPLE position should be corrected
When Alice increase WETH position 150,000 USD
Then Alice's WETH position should be corrected
When Alice sell APPLE position 20,000 USD
Then Revert InsufficientLiquidity
And WETH's market state should be corrected
And APPLE's market state should be corrected
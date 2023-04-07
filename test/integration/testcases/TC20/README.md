## TC20 - Trade with max utilization

### Scenario: Prepare environment
Given Max Utilization is 80%
And BTC price is 20,000 USD
And WETH price is 1,500 USD
And APPLE price is 152 USD
And Bob provide liquidity 5 btc
And Alice deposit 5 btc as Collateral
And Bob deposit 0.5 btc as Collateral

### Scenario: Traders buy / sell
When Alice sell WETH 600,000 USD
Then Alice's WETH position should be corrected
When Bob buy APPLE 100,000 USD
Then Revert InsufficientLiquidity
When Bob buy APPLE 20,000 USD
Then Bob's APPLE position should be corrected
When Alice sell more WETH position 150,000 USD
Then Alice's WETH position should be corrected
When Alice sell APPLE position 20,000 USD
Then Revert InsufficientLiquidity

### Scenario: TVL has increased when price changed
When BTC price pump to 22,000 USD
Then TVL should be increased
And Alice sell APPLE position 20,000 USD
Then Alice should has APPLE short position

### Scenario: TVL has decreased when price changed
When BTC price has changed back to 20,000 USD
Then TVL should be reduced
And Alice fully close APPLE's position
Then Alice Apple's position should be gone
And Alice's balances should be corrected
And Bob's balances should be corrected
And WETH's market state should be corrected
And APPLE's market state should be corrected

## TC11 - not allow trader to do trade when market has beed delisted

### Scenario: Prepare environment
Given Bob provide 1 btc as liquidity
And Btc price is 20,000 USD
And WETH price is 1,500 USD
When Alice deposit collateral 0.1 btc for sub-account 0
And Bob deposit collateral 0.2 btc for sub-account 0
Then Alice's sub-account 0 should has 0.1 btc
Then Bob's sub-account 0 should has 0.2 btc

### Scenario: Traders trade normally
Given Alice buy position at WETH for 3000 USD
And Alice sell position at APPLE for 3000 USD
And Bob buy position at APPLE for 3000 USD

### Scenario: Delist market & Traders try to manage position
When APPLE's market has been delist
And Alice try increase APPLE position for 3000 USD
Then Revert MarketDelisted
And Alice try to fully close APPLE position
Then Still Revert MarketDelisted
When Alice try increase WETH position for 3000 USD
Then Alice has correct position info

### Scenario: Bot close all traders position in delisted market
When Bot close all position under APPLE's market
Then all positions should be closed

### Scenario: Traders try to trade on delist market again
When Bob try buy APPLE's market again
Then Revert MarketDelisted

### Scenario: List new market and Trader could trade
When re-list APPLE's market with new ID
And Bob try buy APPLE's market 3,000 USD again
Then Bob APPLE's position shoule be corrected
And old APPLE's market should not has any position
And new APPLE's market state should corrected
And WETH's market should be corrected

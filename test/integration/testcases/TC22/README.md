## TC22 - Trade with max position size

### Scenario: Prepare environment
Given BTC price is 20,000 USD
And WETH price is 1,500 USD
And APPLE price is 152 USD
And Bob provide liquidity 10 btc
And Alice deposit 5 btc as Collateral
And Bob deposit 5 btc as Collateral
And Cat deposit 5 btc as Collateral

### Scenario: Trader trade on Crypto (WETH)
When Alice buy WETH 7,000,000 USD
Then Alice's position should be corrected 
When Bob buy WETH 4,000,000 USD
And Revert ITradeService_PositionSizeExceed
But Bob can sell WETH 8,000,000 USD
Then Bob's position should be corrected
When Carol sell WETH 3,000,000 USD
And Revert ITradeService_PositionSizeExceed

### Scenario: Trader trade on Stock (APPLE)
When Alice sell APPLE 600,000 USD
Then Alice's position should be corrected 
When Carol buy APPLE 10,000,000 USD
Then Carol's position should be corrected 
When Bob's buy APPLE 1 USD
And Revert ITradeService_PositionSizeExceed
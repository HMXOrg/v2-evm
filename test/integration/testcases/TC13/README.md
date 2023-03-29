## TC13 - Collateral & Trade management with bad price

### Scenario: Prepare environment
Given Bob provide 1 btc as liquidity
And Btc price is 20,000 USD
And WETH price is 1,500 USD
And JPY price is 136.123 USDJPY


### Scenario: Trader deposit normally
When Alice deposit collateral 1 btc
And Alice deposit collateral 10000 usdc
Then Alice's balances should be corrected

### Scenario: BTC has bad price
When found bad price in BTC
And Alice deposit more 0.1 btc
Then Revert BadPrice
And Alice withdraw 0.1 btc
Then Revert BadPrice
And Alice withdraw 500 USDC
Then Alice received collateral back correctly

### Scenario: BTC price comeback
When BTC price is healthy
And Alice withdraw 0.1 btc
Then Alice's balances should be corrected
And Bob deposit 0.1 btc
Then Bob's balances should be corrected

### Scenario: Trader do trade normally
Given Alice buy BTC 100 USD
And Alice sell at JPY 10000 USD

### Scenario: JPY has bad price
When found bad price in JPY
And Alice try to close JPY's position
Then Revert BadPrice 
And Alice's JPY position and balance should be not affected
When Bob buy position at JPY 20000 USD
And Bob's JPY position and balance should be not affected

### Scenario: JPY price comeback
When JPY price is healthy
And Alice close position
Then Alice's JPY position and balance should be not affected

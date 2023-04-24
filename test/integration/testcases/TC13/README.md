## TC13 - Collateral & Trade management with bad price

## This case is obsoleted due to the new EcoPyth which removed the confidence from the price feeds.

### Scenario: Prepare environment
Given Btc price is 20,000 USD
And WETH price is 1,500 USD
And JPY price is 136.123 USDJPY
And USDC price is 1 USD
And Bob provide 1 btc as liquidity


### Scenario: Trader deposit normally
When Alice deposit collateral 1 btc
And Alice deposit collateral 10000 usdc
And Bob deposit collateral 2000 usdc
Then Alice's balances should be corrected
And Bob's balances should be corrected

### Scenario: BTC has bad price
When found bad price in BTC
And Alice deposit more 0.1 btc
Then Alice's balances should be corrected
When Alice withdraw 0.1 btc
Then Revert PythAdapter_ConfidenceRatioTooHigh
When Alice withdraw 500 USDC
Then Revert PythAdapter_ConfidenceRatioTooHigh 
When BOB withdraw 500 USDC
Then Bob's balances should be corrected

### Scenario: BTC price comeback
When BTC price is healthy
And Alice withdraw 0.1 btc
Then Alice's balances should be corrected
And Bob deposit 0.1 btc
Then Bob's balances should be corrected

### Scenario: Trader do trade normally
When Alice buy BTC 100 USD
And Alice sell at JPY 10000 USD
Then Alice's position info should be corrected

### Scenario: JPY has bad price
When found bad price in JPY
And Alice try to close JPY's position
Then Revert PythAdapter_ConfidenceRatioTooHigh 
And Alice's JPY position and balance should not be affected
And Alice try close BTC's position
Then Revert PythAdapter_ConfidenceRatioTooHigh because Alice's has JPY's position
When Bob buy position at JPY 20000 USD
Then Revert PythAdapter_ConfidenceRatioTooHigh
But Bob try buy BTC 300 USD
Then Bob's position should be corrected

### Scenario: JPY price comeback
When JPY price is healthy
And Alice close JPY's position
Then Alice's positions and balance should be corrected

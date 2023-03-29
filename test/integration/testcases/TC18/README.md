## TC18 - Trade with Max profit

### Scenario: Prepare environment
Given Bob provide 1 btc as liquidity
And WETH price is 1,500 USD
And APPLE price is 152 USD
And Alice deposit 1 btc as Collateral

### Scenario: Alice trade on WETH's market
When Alice buy WETH 12,000 USD
Then Alice's WETH position should be corrected

### Scenario: WETH Price pump up 10% and Alice take profit
When Price pump to 1,650 USD
And Alice partial close for 3,000 USD
Then Alice should get profit correctly

### Scenario: Bot force close Alice's position, when alice position profit reached to reserve
When Bot force close ALICE's WETH position
Then Alice should get profit correctly
And Alice's WETH position should be gone

### Scenario: Alice trade on APPLE's market, and profit reached to reserve
When Alice sell APPLE 3,000 USD 
And APPLE's price dump to 136.8 USD (reached to max reserve)
And Alice increase short position at APPLE 3,000 USD

### Scenario: Bot couldn't force close Alice's position
When Bot force close ALICE's WETH position
Then Revert ReservedValueStillEnough

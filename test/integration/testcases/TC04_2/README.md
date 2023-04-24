## TC04.2 - manage position, adjust with profit and loss

### Scenario: Prepare environment
Given Bob provide 1 btc as liquidity
And Btc price is 20,000 USD
And APPLE price is 150 USD
When Alice deposit 1 btc as Collateral
And Bob deposit 1 btc as Collateral
Then Alice should has btc balance 1 btc
And Bob also should has btc balance 1 btc

### Scenario: Alice & Bob open BTC position at different price
When Alice open long position 1,500 USD
Then Alice should has correct long position
And market's state should be corrected
When BTC price is pump to 21,000 USD
When Bob open long position 3,000 USD
Then Bob should has correct long position
And market's state should be corrected

### Scenario: Alice partail close & Bob fully close BTC positions
When Alice partially close BTC 300 USD (profit)
Then Alice should has correct long position
And market's state should be corrected
When BTC price is dump to 20,000 USD
When Bob fully close (loss)
Then Bob BTC position should be closed
And market's state should be corrected

### Scenario: Alice & Bob open APPLE position at different price
When Alice open short position 1,500 USD
Then Alice should has correct short position
And market's state should be corrected
When APPLE price is pump to 157.5 USD
When Bob open short position 6,000 USD
Then Bob should has correct short position
And market's state should be corrected

### Scenario: Alice partail close & Bob fully close APPLE positions
When Alice partially close APPLE 600 USD (loss)
Then Alice should has correct short position
And market's state should be corrected
When APPLE price is dump to 150 USD
When Bob fully close (profit)
Then Bob APPLE position should be closed
And market's state should be corrected
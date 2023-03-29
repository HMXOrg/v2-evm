## TC12 - limit number of position per sub-account

### Scenario: Prepare environment
Given Bob provide 1 btc as liquidity
And Btc price is 20,000 USD
And WETH price is 1,500 USD
And Max Number of position 2
When Alice deposit collateral 1 btc for sub-account 0
Then Alice should has btc balance 1 btc

### Scenario: Alice open multiple position in sub-account 0
When Alice open long position at WETH 3,000 USD
And Alice open long position at JPY 3,000 USD
And Alice open short position at APPLE 3,000 USD
Then Revert because reach limit 2 position per sub-account
And Alice should has only 2 positions

### Scenario: Bob open position in sub-account 0
Given Bob deposit collateral 1 btc for sub-account 0
When Bob open long position at WBTC 30,0000 USD
Then Bob should has corrected position

### Scenario: Alice try open with another sub-account
Given Alice deposit collateral 1 btc for sub-account 1
When alice open short position at APPLE 3,000 USD again with sub-account 1
Then Alice should has corrected position

### Scenario: Alice fully close position and open another position
When Alice close position at JPY
Then Alice should able to open short position at APPLE 3,000 USD

### Scenario: Alice flip position direction APPLE position
When Alice decrease short position at APPLE 6,000 USD
Then Alice should has long position of APPLE 3,000 USD
And Asset class's reserve and Market's state should be corrected

### Scenario: Max position changed and Alice could close position
When Admin set max position to be 1
Then Alice should't open more position at JPY
And Alice could close APPLE position
And Apple position size should be 0
## TC04 - manage position, adjust and flip

### Scenario: Prepare environment
Given Bob provide 1 btc as liquidity
And Btc price is 20,000 USD
And WETH price is 1,500 USD
When Alice deposit 1 btc as Collateral
Then Alice should has btc balance 1 btc

### Scenario: Alice open long position and increase long position
When Alice open long position 15,000 USD
Then Alice should has correct long position
And Alice increase long position for 3,000 USD
Then Alice should has correct long position
And asset class reservce should be corrected
And market position size shoule be corrected

### Scenario: Alice decrease long position and flip to short position
When Alice decrease long position 21,000 USD
Then Alice should has correct short position
And asset class reservce should be corrected
And market position size shoule be corrected

### Scenario: Alice short long position and increase short position
When Alice increase short position for 3,000 USD
Then Alice should has correct position
Then Alice decrease short position for 30,000 USD
Then Alice should has correct long position
And asset class reservce should be corrected
And market position size shoule be corrected


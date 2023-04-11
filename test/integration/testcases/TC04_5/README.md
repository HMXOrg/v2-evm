## TC04.5 - manage position, adjust with profit and loss

### Scenario: Prepare environment
Given Bob provide 1 btc as liquidity
And Btc price is 20,000 USD
And JPY price is 0.007346297098947275625720855402 USD (136.123 USDJPY)
When Alice deposit 1 btc as Collateral
And Bob deposit 1 btc as Collateral
Then Alice should has btc balance 1 btc
And Bob also should has btc balance 1 btc

### Scenario: Alice open & update long position with profit (BTC)
When Alice open long position 1,000 USD
Then Alice should has correct long position
And market's state should be corrected
When BTC price is pump to 22,000 USD
And Alice increase long position for 100 USD
Then Alice should has correct long position
And market's state should be corrected

### Scenario: Bob open & update long position with loss (BTC)
When Bob open long position 1,000 USD
Then Bob should has correct long position
And market's state should be corrected
When BTC price is dump to 20,000 USD
And Bob increase long position for 100 USD
Then Bob should has correct long position
And market's state should be corrected

### Scenario: Alice open & update short position with loss (JPY)
When Alice open short position 1,000 USD
Then Alice should has correct short position
And market's state should be corrected
When JPY price is pump to 0.00741976006993674838197806395602 USD (134.775 USDJPY)
And Alice increase short position for 100 USD
Then Alice should has correct short position
And market's state should be corrected

### Scenario: Bob open & update short position with profit (JPY)
When Bob open short position 1,000 USD
Then Bob should has correct short position
And market's state should be corrected
When JPY price is dump to 0.007346297098947275625720855402 USD (136.123 USDJPY)
And Bob increase short position for 100 USD
Then Bob should has correct short position
And market's state should be corrected

Scenario: Trader able to adjust position and support flip position direction
Given Bob provide 1 btc as liquidity
And Btc price is 20,000 USD
And WETH price is 1,500 USD
When Alice deposit 1 btc as Collateral
Then Alice should has btc balance 1 btc

Scenario: Alice open long position and increase long position
When Alice open long position 10,000 USD
Then Alice should has correct position
When weth price change from 1,500 USD to 1,575
And Alice increase position size for 2500 USD
Then Alice should has correct position
And asset class reservce should be corrected
And market 

Scenario: Alice decrease long position and flip to short position


Scenario: Alice short long position and increase short position


Scenario: Alice decrease short position and flip to long position




TC04 - manage position, adjust and flip
Steps (Market):
- alice deposit BTC 100 USD
- alice buy market WETH 100 USD -> LONG 100
- alice buy market WETH 20 USD  -> LONG 120

- alice sell market WETH 150 USD -> SHORT 30 (flip)
- alice sell limit WETH 20 USD -> SHORT 50

- alice buy market WETH 70 USD -> LONG 20 (flip)
Steps (Limit):

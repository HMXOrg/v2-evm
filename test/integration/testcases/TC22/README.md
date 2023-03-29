TC22 - Max OI per market
Leverages:
  - WETH - 100x (1%)
  - APPLE - 20x (5%)
Steps (Market):
- liquidity provider 3,000,000 USD
- alice deposit 100,000 USD
- bob deposit 100,000 USD
- cat deposit 100,000 USD
- alice buy WETH position 7,000,000 USD 
  - ALICE IMR 70,000 USD
  - ALICE free collat 30,000 USD remaining 
- bob buy WETH position 4,000,000 USD - revert
- bob sell WETH position 8,000,000 USD
  - BOB IMR 80,000 USD
  - BOB free collat 20,000 USD remaining 
- alice sell WETH position 3,000,000 USD - revert
- alice sell APPLE position 600,000 USD
  - ALICE IMR 100,000 USD
  - ALICE free collat 0 USD remaining
- cat buy APPLE position 10,000,000 USD


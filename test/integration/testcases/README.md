TC02 - trader could take profit both long and short position
Prices:
  WBTC - 20,000 USD
  WETH -  1,500 USD
  JPY  - 136.123 (USDJPY) => 0.007346297099
Steps (market): 
- alice deposit BTC 200 USD
- open weth long position with 200,000 USD (1000x) - revert poor
- open weth long position with 300 USD
- alice withdraw 200 USD - revert
- weth pump price up 5% (1650 USD)
- partial close position for 150 USD
- alice open short JPY position 5000 USD
- jpy pump price 3%
- alice fully close JPY position
Steps (limit):
- bob deposit BTC 100 USD
- bob create buy BTC position order at price 18,000 USD with 500 USD (order 0)
- price BTC dump to 17,500 USD
- execute order 0 - not trigger
- price BTC dump to 17,999.99 USD
- execute order 0 - BOB will has long position 500 USD with entry price 18,000 USD
- bob create sell BTC position order at price 18,900 USD with 500 USD (order 1)
- price BTC pump to 18,500 USD
- execute order 1 - not trigger
- price BTC pump to 18,900.01 USD
- execute order 1 - BOB fully close short at 18,900 USD
- bob create sell BTC position order at price 21,000 USD with 500 USD (order 2)
- price BTC pump to 21,050 USD
- execute order 2 - BOB will has short position 500 USD with entry price 21,000 USD
- bob create buy BTC position order at price 18,900 USD with 500 USD (order 3)
- price BTC dump to 17,999.99 USD
- execute order 3 - BOB fully close long at 18,900 USD


TC03 - trader loss both long and short position
Prices:
  WBTC - 20,000 USD
  WETH -  1,500 USD
  JPY  - 136.123 (USDJPY) => 0.007346297099
Steps (market): 
- alice deposit BTC 200 USD
- open weth short position with 200,000 USD (1000x) - revert poor
- open weth short position with 300 USD
- weth pump price up 5% (1650 USD)
- partial close position for 150 USD
- alice open long JPY position 5000 USD
- jpy dump price 3%
- alice fully close JPY position
Steps (limit):
- bob deposit BTC 100 USD
- bob create sell BTC position order at price 22,000 USD with 500 USD (order 0)
- price BTC pump to 21,999.99 USD
- execute order 0 - not trigger
- price BTC pump to 22,000.0001 USD
- execute order 0 - BOB will has short position 500 USD with entry price 22,000 USD
- bob create buy BTC position order at price 23,100 USD with 500 USD (order 1)
- price BTC pump to 23,000 USD
- execute order 1 - not trigger
- price BTC pump to 23,500 USD
- execute order 1 - BOB fully close short at 23,100 USD
- bob create buy BTC position order at price 23,000 USD with 500 USD (order 2)
- price BTC dump to 22,999 USD
- execute order 2 - BOB will has long position 500 USD with entry price 23,000 USD
- bob create sell BTC position order at price 22,500 USD with 500 USD (order 3)
- price BTC dump to 21,000 USD
- execute order 3 - BOB fully close long at 22,500 USD


TC04 - manage position, adjust and flip
Steps (Market):
- alice deposit BTC 100 USD
- alice buy market WETH 100 USD -> LONG 100
- alice buy market WETH 20 USD  -> LONG 120

- alice sell market WETH 150 USD -> SHORT 30 (flip)
- alice sell limit WETH 20 USD -> SHORT 50

- alice buy market WETH 70 USD -> LONG 20 (flip)
Steps (Limit):

TC05 - liquidation position
- alice deposit collateral 0.05 BTC price 20,000 USD
- alice buy JPYUSD 100,000 USD at JPY price 0.008 USD
- JPYUSD dumped to 0.007945967422 USD (Equity < MMR)
- liquidate alice's account

TC08 - check IMR, MMR
- alice deposit collateral 0.05 BTC price 20,000 USD
- alice buy JPYUSD 100,000 USD at JPY price 0.008 USD
- alice sell BTCUSD 50,000 USD at BTC price 23_000 USD
- BTC pumped to 23,100 USD (Equity < MMR)
- alice try to withdraw collateral
- alice try to buy BTCUSD 50,000 USD at BTC price 23,100 USD (close position)
- alice deposit collateral (Equity < IMR)
- alice try to withdraw collateral
- try to liquidate alice account
- alice deposit collateral (Equity < IMR)
- try to liquidate alice account
- JPYUSD dumped to 0.00790513834 USD (Equity < MMR)
- liquidate alice's account

TC09 - liquidate user has sub account more than 1
- alice's sub account 0 deposit collateral 0.05 BTC price 20,000 USD
- alice's sub account 1 deposit collateral 0.05 BTC price 20,000 USD
- alice's sub account 0 buy JPYUSD 100,000 USD at JPY price 0.008 USD
- alice's sub account 1 buy BTCUSD 10,000 USD at JPY price 20,000 USD
- JPYUSD dumped to 0.007945967422 USD
- liquidate alice's sub account 0
- try liquidate alice's sub account 1

TC10 - liquidate when market close
- alice's sub account 0 deposit collateral 0.1 BTC at price 20,000 USD
- alice's sub account buy JPYUSD 100,000 USD at price 0.008 USD
- alice's sub account buy BTCUSD 10,000 USD at price 23,00 USD
- alice's sub account buy APPLE 10,000 USD at price 152 USD
- JPYUSD dumped to 0.007874015748 USD
- APPLE pumped to 155 USD
- liquidate alice's sub account 0

TC11 - list/delist market
- alice deposit BTC 100 USD
- bob deposit BTC 50 USD
- alice open long position WETH 20 USD
- alice open short position APPLE 20 USD
- bob open long position APPLE 200 USD
- delist APPLE market
- alice increase APPLE position - revert
- alice fully close APPLE position - revert
- bot force close all positions in APPLE
- bob open position APPLE 200 USD - revert
- list new APPLE market (diff index)
- bob open position APPLE 200 USD

TC12 - limit position (max 2)
- alice deposit BTC 100 USD
- alice open position WETH 20 USD
- alice open position WBTC 20 USD
- alice open position JPY 20 USD - revert
- bob open position WETH
- alice fully close position WBTC
- alice open position JPY 20 USD

TC13 - bad price confidencial, then couldn't interact with trade and collateral things
Prices:
- BTC
- USDT
- JPY
Steps (collateral):
- alice deposit BTC 100 USD
- alice deposit USDT 100 USD
- set bad price for BTC
- alice withdraw BTC 20 USD - revert
- alice deposit BTC 50 USD - revert
- alice deposit USDT 50 USD
- alice withdraw USDT 20 USD
- set good price for BTC
- alice withdraw BTC 20 USD
- bob deposit BTC 25 USD
Steps (trade):
- alice open long position BTC 100 USD
- alice open short position JPY 100 USD
- set bad price JPY
- partial close JPY - revert
- alice increase JPY position - revert
- bob open JPY - revert
- set good price JPY
- alice fully close short JPY position

TC17 - liquidate when bad debt
- alice's sub account 0 deposit collateral 0.1 BTC at price 20,000 USD
- alice's sub account buy JPYUSD 100,000 USD at price 0.008 USD
- alice's sub account buy BTCUSD 10,000 USD at price 23,000 USD
- alice's sub account buy APPLE 10,000 USD at price 152 USD
- JPYUSD dumped to 0.007692307692 USD
- BTCUSD pumped to 23,500 USD
- APPLE pumped to 155 USD
- liquidate alice's sub account 0

TC18 - react max profit, trader couldn't close position by themself, but can increase
Prices:
  WETH - 1500 USD
  APPLE - 152 USD
Steps:
- alice add collateral 100 USD
- open WETH position 10000 USD (10x) (WETH max Leverage 100x)
  - IMR 10 USD
  - Max profit = IMR * 900% = 90 USD
- pump price up 10% (1650 USD)
- alice partial close 500 USD, take 900% profit (45 USD)
- bot try force take profit 500 USD
- alice open short APPLE 2000 USD
  - IMR 20 USD
  - Max profit = IMR * 900% = 180 USD
- dump price down 10% (136.8 USD)
  - profit = 10% of 2000 USD (position size) = 200 USD
- alice increase short position to 5000 USD (+3000 USD)
  - IMR 50 USD
  - Max profit = IMR * 900% = 450 USD
- bot try force take profit - revert
- alice fully close should get profit 200 USD

TC20 - Reserve should not more than TVL
Leverages:
  - WETH - 100x (1%)
  - APPLE - 20x (5%)
Steps (Market):
- liquidity provider 100,000 USD
- alice deposit 100,000 USD
- bob deposit 10,000 USD
- alice sell WETH 1,000,000 USD (reserve)
  - IMR 10,000 USD
  - Reserve 90,000 USD
- bob buy APPLE 20,000 USD
  - IMR 1,000 USD
  - Reserve 9,000 USD (total 99,000)
- alice buy more WETH 50,000 USD - revert reserve not enough
  - IMR 500 USD
  - Reserve 4,500 USD (total 103,500)

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

TC37 - liquidate when profit delta and funding fee but loss borrowing fee
- alice's sub account 0 deposit collateral 0.1 BTC at price 20,000 USD
- alice's sub account 1 deposit collateral 1 BTC at price 20,000 USD
- alice's sub account 1 buy BTCUSD 110,000 USD at price 20,000 USD
- alice's sub account 0 buy BTCUSD 100,000 USD at price 20,000 USD
- BTCUSD pumped to 20,100 USD
- liquidate alice's sub account 0
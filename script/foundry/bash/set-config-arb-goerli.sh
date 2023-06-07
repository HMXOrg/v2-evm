#!/bin/bash
source .env

TARGET_RPC="https://goerli-rollup.arbitrum.io/rpc"
echo $TARGET_RPC

echo "Set Config"
forge script ./config/01_SetConfig.s.sol:SetConfig --rpc-url $TARGET_RPC --broadcast --with-gas-price 110000000

echo "Set Markets"
forge script ./config/02_SetMarkets.s.sol:SetMarkets --rpc-url $TARGET_RPC --broadcast --with-gas-price 110000000

echo "Set Oracle"
forge script ./config/03_SetOracle.s.sol:SetOracle --rpc-url $TARGET_RPC --broadcast --with-gas-price 110000000

echo "Set Collateral Tokens"
forge script ./config/04_SetCollateralTokens.s.sol:SetCollateralTokens --rpc-url $TARGET_RPC --broadcast --with-gas-price 110000000

echo "Set Asset Config"
forge script ./config/05_SetAssetConfig.s.sol:SetAssetConfig --rpc-url $TARGET_RPC --broadcast --with-gas-price 110000000

echo "Set Whitelist"
forge script ./config/06_SetWhitelist.s.sol:SetWhitelist --rpc-url $TARGET_RPC --broadcast --with-gas-price 110000000

echo "Set HLP"
forge script ./config/07_SetHLP.s.sol:SetHLP --rpc-url $TARGET_RPC --broadcast --with-gas-price 110000000
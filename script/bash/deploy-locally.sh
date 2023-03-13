#!/bin/bash
source .env

TARGET_RPC="https://goerli-rollup.arbitrum.io/rpc"
echo $TARGET_RPC

# echo "Deploy LOCAL!!! contracts"
# forge script ./deployment/00_DeployLocalContract.s.sol:DeployLocalContract --rpc-url $TARGET_RPC --broadcast

echo "Deploy Pyth adapter"
forge script ./deployment/01_DeployPythAdapter.s.sol:DeployPythAdapter --rpc-url $TARGET_RPC --broadcast

echo "Deploy Oracle"
forge script ./deployment/02_DeployOracleMiddleware.s.sol:DeployOracleMiddleware --rpc-url $TARGET_RPC --broadcast

echo "Deploy Storages & PLP token"
forge script ./deployment/03_DeployStoragesAndPLPToken.s.sol:DeployStoragesAndPLPToken --rpc-url $TARGET_RPC --broadcast

echo "Deploy Calculators"
forge script ./deployment/04_DeployCalculators.s.sol:DeployCalculators --rpc-url $TARGET_RPC --broadcast

echo "Set ConfigStorage"
forge script ./deployment/05_SetConfigStorage.s.sol:SetConfigStorage --rpc-url $TARGET_RPC --broadcast

echo "Deploy Services"
forge script ./deployment/06_DeployServices.s.sol:DeployServices --rpc-url $TARGET_RPC --broadcast

echo "Deploy Handlers"
forge script ./deployment/07_DeployHandlers.s.sol:DeployHandlers --rpc-url $TARGET_RPC --broadcast
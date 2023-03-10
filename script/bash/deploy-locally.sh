#!/bin/bash
source .env

echo "Deploy LOCAL!!! contracts"
forge script ./deployment/00_DeployLocalContract.s.sol:DeployLocalContract --fork-url http://localhost:8545 --broadcast

echo "Deploy Pyth adapter"
forge script ./deployment/01_DeployPythAdapter.s.sol:DeployPythAdapter --fork-url http://localhost:8545 --broadcast

echo "Deploy Oracle"
forge script ./deployment/02_DeployOracleMiddleware.s.sol:DeployOracleMiddleware --fork-url http://localhost:8545 --broadcast

echo "Deploy Storages & PLP token"
forge script ./deployment/03_DeployStoragesAndPLPToken.s.sol:DeployStoragesAndPLPToken --fork-url http://localhost:8545 --broadcast

echo "Deploy Calculators"
forge script ./deployment/04_DeployCalculators.s.sol:DeployCalculators --fork-url http://localhost:8545 --broadcast

echo "Set ConfigStorage"
forge script ./deployment/05_SetConfigStorage.s.sol:SetConfigStorage --fork-url http://localhost:8545 --broadcast

echo "Deploy Services"
forge script ./deployment/06_DeployServices.s.sol:DeployServices --fork-url http://localhost:8545 --broadcast

echo "Deploy Handlers"
forge script ./deployment/07_DeployHandlers.s.sol:DeployHandlers --fork-url http://localhost:8545 --broadcast
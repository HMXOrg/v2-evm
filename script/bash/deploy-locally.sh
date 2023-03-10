#!/bin/bash
source .env

forge script ./deployment/00_DeployLocalContract.s.sol:DeployLocalContract --fork-url http://localhost:8545 --broadcast
forge script ./deployment/01_DeployPythAdapter.s.sol:DeployPythAdapter --fork-url http://localhost:8545 --broadcast
forge script ./deployment/02_DeployOracleMiddleware.s.sol:DeployOracleMiddleware --fork-url http://localhost:8545 --broadcast
forge script ./deployment/03_DeployStoragesAndPLPToken.s.sol:DeployStoragesAndPLPToken --fork-url http://localhost:8545 --broadcast
forge script ./deployment/04_DeployCalculators.s.sol:DeployCalculators --fork-url http://localhost:8545 --broadcast
forge script ./deployment/05_SetConfigStorage.s.sol:SetConfigStorage --fork-url http://localhost:8545 --broadcast
forge script ./deployment/06_DeployServices.s.sol:DeployServices --fork-url http://localhost:8545 --broadcast
forge script ./deployment/07_DeployHandlers.s.sol:DeployHandlers --fork-url http://localhost:8545 --broadcast
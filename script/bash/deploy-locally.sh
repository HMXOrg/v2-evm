#!/bin/bash
source .env

forge script ../deployment/01_DeployPythAdapter.s.sol:DeployPythAdapter --fork-url http://localhost:8545 --broadcast
forge script ../deployment/02_DeployOracleMiddleware.s.sol:DeployOracleMiddleware --fork-url http://localhost:8545 --broadcast
forge script ../deployment/03_DeployStorages.s.sol:DeployStorages --fork-url http://localhost:8545 --broadcast
forge script ../deployment/04_DeployCalculators.s.sol:DeployCalculators --fork-url http://localhost:8545 --broadcast
forge script ../deployment/05_DeployServices.s.sol:DeployServices --fork-url http://localhost:8545 --broadcast
forge script ../deployment/06_DeployHandlers.s.sol:DeployHandlers --fork-url http://localhost:8545 --broadcast
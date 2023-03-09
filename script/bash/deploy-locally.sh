#!/bin/bash
source .env

forge script ../deployment/01_DeployCore.s.sol:DeployCore --fork-url http://localhost:8545 --broadcast

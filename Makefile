-include .env

export DAPP_REMAPPINGS=@config/=config/$(NETWORK)

test-fork:
	@echo Run all fork tests on $(NETWORK)
	@forge test -vvvv --fork-url $(ARBI_MAINNET_RPC) --fork-block-number $(FORK_BLOCK_NUMBER) --match-contract \ForkTest\

test-unit:
	@echo Run all unit tests
	@forge test -vvv --watch --no-match-contract \ForkTest\
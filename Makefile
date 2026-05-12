-include .env

.PHONY: all install build test clean deploy-sepolia

all: clean build test

clean:
	forge clean

build:
	forge build

test:
	forge test

test-verbose:
	forge test -vvvv

install:
	forge install

deploy-sepolia:
	forge script script/DeployMerkleAirdrop.s.sol:DeployMerkleAirdrop --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API}

# PRIVATE_KEY in .env must control `user` in script/ClaimAirdrop.s.sol (same leaf as script/target/input.json).
claim-airdrop:
	forge script script/ClaimAirdrop.s.sol:ClaimAirdrop --private-key ${PRIVATE_KEY} --rpc-url ${RPC_URL} --broadcast
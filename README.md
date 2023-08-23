# paymaster-examples

## Onchain Summer 

### Overview
Paymaster-examples is a series of  ERC-4337 Paymaster contracts by 0xSilas which are able to sponsor gas fees for authorized senders. 

### Features
- Give free transactions based on owning a NFT of a certain collection.
- Give free transactions based on a token-bound account(ERC6551) of a certain collection.

### Contract
The contract inherits from BasePaymaster.

#### Functions
- constructor: Initializes the Paymaster contract with the given parameters.
- validatePaymasterUserOp: Validates a paymaster user operation for the transaction.

### Usage
Deploy the Paymaster contract, providing the required parameters such as EntryPoint contract, ERC6551 registry address and NFT token contract addresses. For more information, please refer to the comments within the contract source code.

### Development setup
This repository uses foundry for development, and assumes you have already installed foundry.

### foundry

Foundry is used for unit tests

1. install dependencies
```shell
npm install
forge install
```

2. run tests
```shell
forge test
```




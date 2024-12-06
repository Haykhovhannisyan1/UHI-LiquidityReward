# UHI-LiquidityReward
This repository contains the final project developed during the Uniswap Hook Incubator program. It implements a hook that provides fee discounts to users who are Liquidity Providers (LPs) with at least 5000 USDC on Uniswap.

To verify a user’s eligibility, the hook leverages Brevis to read events from the PositionManager contract and generates a zero-knowledge (ZK) proof to confirm that the user is indeed an LP.

The primary goal of this hook is to incentivize users to become LPs on Unichain by offering fee discounts. However, since Brevis currently does not support Unichain, the implementation is demonstrated on Ethereum instead.

## Environment Requirements

- Go >= 1.20 (https://go.dev/doc/install)
- Node.js LTS (https://nodejs.org/en)
### Start Prover (for testing)

```bash
cd prover
make start
```
# [App](./app)

The Node.js project in ./app is a simple program that does the following things:

1. call the Go prover with some transaction data to generate token transfer volume proof
2. call Brevis backend service and submit the token transfer volume proof
3. wait until the final proof is submitted on-chain and our contract is called

## How to Run

```bash
cd app
npm run start [TransactionHash]
```
Example for Normal Flow
```bash
npm run start 0x8a7fc50330533cd0adbf71e1cfb51b1b6bbe2170b4ce65c02678cf08c8b17737
```
# [Contracts](./contracts)

The app contract [TokenTransferZkOnly.sol](./contracts/contracts/TokenTransferZkOnly.sol) is called
after you submit proof is submitted to Brevis when Brevis'
systems submit the final proof on-chain.
It does the following things when handling the callback:

1. checks the proof was associated with the correct vk hash
2. decodes the circuit output
3. emit a simple event

## Init

```bash
cd contracts
npm install
```

## Test

```bash
npm run test
```

## Deploy

Rename `.env.template` to `.env`. Fill in the required env vars.

```bash
npx hardhat deploy --network sepolia --tags TokenTransferZkOnly
```
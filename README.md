# SPACERIDERS SMARTCONTRACTS

## ⚠️ REQUIREMENTS

- NodeJS v16
- Yarn
- Hardhat

## ⚙️ INSTALLATION

First of all, install Hardhat.

```bash
yarn global add hardhat-shorthand
```

Clone the project's repository.

```bash
git clone git@github.com:redigaffi/spaceriders-smartcontracts.git
```

Inside the project's folder, install dependencies.

```bash
yarn install
```

Copy the env var file `.env.example` as `.env`.

```bash
cp .env.example .env
```

Edit .env file to add an Etherscan API Key and the account to manage in testnet and mainnet. In a local environment, this values can be fictional.

Start Hardhat to initiate a local simulated blockchain.

```bash
hh node
```

Open another terminal. Deploy the smart contracts in your local blockchain while Hardhat is running.

```bash
hh run ./scripts/migration.js --network local
```

Copy the generated addresses, go to the `spaceriders-apiv2` project folder and paste them into the `src/static/contract_addresses/contracts.local.json` file. 

Then configure a new network in your Metamask pointing to your local blockchain. Go to `Settings -> Networks -> Add network` and fill the fields with the following information.

```yaml
Network name: Hardhat
New RPC URL: http://localhost:8545
Chain ID: 31337
Currency symbol: ETH
```

Finally, import the first wallet address from Hardhat to Metamask.

## 🚀 USAGE

Start Hardhat.

```bash
hh node
```

Sometimes you may need to deploy the smart contracts again and paste the output into the `src/static/contract_addresses/contracts.local.json` file in `spaceriders-apiv2` project.

```bash
hh run ./scripts/migration.js --network local
```

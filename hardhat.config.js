require("@nomiclabs/hardhat-waffle");
require("@tenderly/hardhat-tenderly");
require("dotenv").config();
const fs = require("fs");
require("@nomiclabs/hardhat-etherscan");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task("hello", "Prints 'Hello, World!'", async () => {
  await hre.run("verify:verify", {
    address: "0xA4bc9e812EDe193E66b807C01b22e3BD71b4aCBF",
    constructorArguments: [
      "0xaF50Cc15980e890EFdba8a6aE47a434AaCEf5d64",
      "0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7",
    ],
  });
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 400,
      },
    },
  },
  tenderly: {
    username: "redigaffi",
    project: "project",
  },
  networks: {
    local: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
      gas: 12000000,
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
      timeout: 1800000,
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      chainId: 97,
      gas: 9721975,
      accounts: process.env.TESTNET_ACCOUNT.split(","), // ends in biea
    },
    mainnet: {
      url: "https://bsc-dataseed1.defibit.io/",
      chainId: 56,
      gasPrice: 7,
      gas: 8721975,
      accounts: process.env.MAINNET_ACCOUNT.split(","), // ends in biea
    },
  },
  etherscan: {
    apiKey: {
      bscTestnet: process.env.ETHERSCAN_API_KEY_BSC,
      bsc: process.env.ETHERSCAN_API_KEY_BSC,
    },
  },
};

require("@nomiclabs/hardhat-waffle");
require('dotenv').config({path:__dirname+'/.env'})
module.exports = {
  defaultNetwork: "localhost",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    hardhat: {
      
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${process.env.INFURA_APIKEY}`,
      accounts: [process.env.KOVAN_PRIVATE_KEY]
    }
  },
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  }
}
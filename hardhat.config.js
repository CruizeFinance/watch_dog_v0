require("@nomiclabs/hardhat-waffle");
require("hardhat-tracer");
require('dotenv').config({path:__dirname+'/.env'})
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    hardhat: {
      forking:{
        url: `https://kovan.infura.io/v3/${process.env.INFURA_APIKEY}`,
      },
      accounts: {
        privateKey:process.env.PRIVATE_KEY
      }
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${process.env.INFURA_APIKEY}`,
      accounts: [process.env.PRIVATE_KEY]
    },
    rinkeby: {
      url: `https://kovan.infura.io/v3/${process.env.RINKEBY_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.8.0",
      },
      {
        version: "0.4.18",
      },
      {
        version: "0.8.2",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        },
      },
    ],
   
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
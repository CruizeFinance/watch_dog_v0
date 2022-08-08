import yargs from "yargs";
import * as dotenv from "dotenv";


import 'hardhat-deploy';
import 'hardhat-tracer';
import 'hardhat-watcher';
import "solidity-coverage";
import "@typechain/hardhat";
import 'hardhat-abi-exporter';
import "hardhat-gas-reporter";
import 'hardhat-contract-sizer';
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import { HardhatUserConfig, task } from "hardhat/config";
import type { HttpNetworkUserConfig } from "hardhat/types";

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});


const argv = yargs.option("network", {
  type: "string",
  default: "hardhat"
})
  .help(false)
  .version(false).argv;

const DEFAULT_MNEMONIC:string = process.env.MNEMONIC || "";

const sharedNetworkConfig: HttpNetworkUserConfig = {
  live: true,
  saveDeployments: true,
  timeout: 8000000,
  gasPrice: "auto",
};
if (process.env.PRIVATE_KEY) {
  sharedNetworkConfig.accounts = [process.env.PRIVATE_KEY];
} else {
  sharedNetworkConfig.accounts = {
    mnemonic: process.env.MNEMONIC || DEFAULT_MNEMONIC,
  };
}
// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  namedAccounts: {
    deployer: 0
  },
  paths: {
    tests: "./test/src",
    cache: "./cache",
    deploy: "./src/deploy",
    sources: "./contracts",
    deployments: "./deployments",
    artifacts: "./artifacts",
  },
  solidity: {
    compilers: [
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            runs: 200,
            enabled: true
          }
        }
      },
      {
        version: "0.8.2",
        settings: {
          optimizer: {
            runs: 200,
            enabled:true
          }
        }
      },
      {
        version: "0.8.0",
        settings: {
          optimizer: {
            runs: 200,
            enabled: true
          }
        }
      },
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            runs: 200,
            enabled: true
          }
        }
      }
    ],
    overrides:{
      "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol":{
        version: "0.8.10",
        settings: { }
      }
    }
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      accounts: {
        accountsBalance: "100000000000000000000000000000000000000000",
        mnemonic: process.env.MNEMONIC || DEFAULT_MNEMONIC
      },
      forking:{
        url:`https://mainnet.infura.io/v3/${process.env.INFURA_KEY}`
      }
    },
    mainnet: {
      ...sharedNetworkConfig,
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_KEY}`,
    },
    rinkeby: {
      ...sharedNetworkConfig,
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_KEY}`,
      chainId: 4,
    },
    ropsten: {
      ...sharedNetworkConfig,
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_KEY}`,
    },
    kovan: {
      ...sharedNetworkConfig,
      url: `https://kovan.infura.io/v3/${process.env.INFURA_KEY}`,
    },
    xdai: {
      ...sharedNetworkConfig,
      url: "https://xdai.1hive.org",
    },
    polygon: {
      ...sharedNetworkConfig,
      url: "https://rpc-mainnet.maticvigil.com/",
    },
    binancesmartchain: {
      ...sharedNetworkConfig,
      url: "https://bsc-dataseed1.binance.org/",
    },
    bsc: {
      ...sharedNetworkConfig,
      url: "https://data-seed-prebsc-1-s2.binance.org:8545/",
      chainId: 97,
    },
    pulsechain: {
      ...sharedNetworkConfig,
      url: "https://rpc.testnet.pulsechain.com",
      chainId: 940,
    },
    optimism: {
      url: "https://mainnet.optimism.io",
      ...sharedNetworkConfig,

    },
  },
  mocha: {
    timeout: 8000000,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false,
  },
  watcher: {
    /* run npx hardhat watch compilation */
    compilation: {
      tasks: ["compile"],
      verbose: true
    },
    /* run npx hardhat watch test */
    test: {
      tasks: [{
        command: 'test',
        params: {
          logs: true, noCompile: false,
          testFiles: [
            "./test/src/aave-integration-v2.spec.ts",
          ]
        }
      }],
      files: ['./test/src/*'],
      verbose: true
    },
    /* run npx hardhat watch ci */
    ci: {
      tasks: [
        "clean", { command: "compile", params: { quiet: true } },
        {
          command: "test",
          params: {
            noCompile: true,
            testFiles: [
              "./test/src/aave-integration-v2.spec.ts",
            ]
          }
        }],
    }
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    gasPrice: 10
  }

};

export default config;

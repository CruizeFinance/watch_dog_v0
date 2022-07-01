// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat

const { ethers } = require("hardhat");

// Runtime Environment's members available in the global scope.
const main = async () => {
    const usdcContract = await ethers.getContractFactory("USDCPool");
    const usdcToken = await usdcContract.deploy();
    const assetContract = await ethers.getContractFactory("AssetPoolUpgradeable");
    const assetToken = await assetContract.deploy();
    console.log("usdc pool deployed at", usdcToken.address);
    console.log("asset pool deployed at", assetToken.address);
  };
  
  main()
    .then(() => {
      process.exit(0);
    })
    .catch((errr) => {
      console.log(errr);
      process.exit(0);
    });

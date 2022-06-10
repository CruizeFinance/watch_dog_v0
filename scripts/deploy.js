// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const main = async () => {
    const [deployer] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("USDCPool");
    const token = await Token.deploy();
    console.log("this is deployed token", token.address);
  };
  
  main()
    .then(() => {
      process.exit(0);
    })
    .catch((errr) => {
      console.log(errr);
      process.exit(0);
    });

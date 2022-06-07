const USDC_Pool = artifacts.require("./USDCPool.sol");
require("chai")
  .use(require("chai-as-promised"))
  .should();
const assert = require("chai").assert;
contract("USDCpool", ([deployer]) => {
  let accounts;
  let USDCPool;
  let result;
  const contractAddress = "0x467Ee5efF19dee84C3236b694e9a4b83E8D10751";
  // deploying the contract ...
  before(async () => {
    accounts = await web3.eth.getAccounts();

    // USDCpPool = await USDC_pool.deployed();

    //working on a specifice  contract address..
    USDCPool = await USDC_Pool.at(contractAddress);
  });

  describe("Contract deployment", async () => {
    it("deployed successfully", async () => {
      const poolAddress = USDCPool.address;
      // console.log(poolAddress)
      assert.notEqual(poolAddress, 0x0);
      assert.notEqual(poolAddress, "");
      assert.notEqual(poolAddress, null);
      assert.notEqual(poolAddress, undefined);
      assert.equal(poolAddress, contractAddress);
    });
  });
  describe("Contract Function testing", async () => {
    it("provide liquidity", async () => {
      let supply = await USDCPool.totalSupply();
      let balance = await USDCPool.totalBalance();
      balance = balance.toNumber();
      supply = supply.toNumber();
      console.log((balance += 1));
      console.log(supply);
      console.log(balance);
      let USDC_Token_value = Math.floor((1 * supply) / (balance - 1));

      console.log("accpeted", USDC_Token_value);
      let liquidityAmount = 1;
      result = await USDCPool.provide(liquidityAmount, {
        from: accounts[1],
        value: 1,
      });

      let USDCtoken = await result.logs[1].args.writeAmount;
      console.log(USDCtoken.toNumber());
      assert.notEqual(USDCtoken, 0);
      assert.notEqual(USDCtoken, "");
      assert.notEqual(USDCtoken, null);
      assert.notEqual(USDCtoken, undefined);
      assert.equal(USDCtoken.toNumber(), USDC_Token_value || 1000);
    });
  });
});

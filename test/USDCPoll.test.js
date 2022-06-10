const { expect } = require("chai");
const { ethers } = require("hardhat");
var should = require('chai').should()

const assert = require("chai").assert;
let [singer, user1] = "";
let UsdcPool;
before("USDCPool", async () => {
  [singer, user1] = await ethers.getSigners();
  //deploying smart contract .
  const usdcPool = await ethers.getContractFactory("USDCPool");
   UsdcPool = await usdcPool.deploy();
  await UsdcPool.deployed();

  // working on a specifce deployed address ..
  // const Exchange = await ethers.getContractFactory("USDCPool", singer);
  // UsdcPool = Exchange.attach("0xa513E6E4b8f2a923D98304ec87F64353C4D5C853");
  console.log(UsdcPool.address);
});

describe("testing Contract functions ..", function() {
  it("provide liquidity", async () => {
    let USDC_Amount = 2;
    let min_Token = 2;
    // getting the total supply and total balance..
    let totalSupply = await UsdcPool.callStatic.totalSupply();
    let balance = await UsdcPool.callStatic.totalBalance();

    //converting big number into INT.
    balance = balance.toNumber();
    totalSupply = totalSupply.toNumber();
    //formula for getting the value of WUSDC that user willl receive.
    balance += 1;
    let Accepted_WUSDC = Math.floor(
      (USDC_Amount * totalSupply) / (balance - 1)
    );
    console.log("Accepted USDC", Accepted_WUSDC);
    let result = await UsdcPool.connect(singer).provide(min_Token, {
      value: USDC_Amount,
    });
    //getting the events.
    const contractReceipt = await result.wait();
    let WUSDC = await contractReceipt.events[1].args.writeAmount;
    assert.notEqual(WUSDC, 0);
    assert.notEqual(WUSDC, "");
    assert.notEqual(WUSDC, null);
    assert.notEqual(WUSDC, undefined);
    assert.equal(WUSDC.toNumber(), Accepted_WUSDC || USDC_Amount * 1000);

    // uint265 never takes an -ve value it will go out of bound .. also you can't pass an -ve in value ..
    // result = await USDCPool.provide(-1, {
    //   from: accounts[1],
    //   value: 1,
    // }).should.be.rejectedWith("Pool: Amount is too small");

    result = await UsdcPool.connect(singer)
      .provide(2000, {
        value: 1,
      })
      .should.be.revertedWith("Pool: Mint limit is too large");

    result = await UsdcPool.connect(singer)
      .provide(0, {
        value: 0,
      }).should.be.revertedWith("Pool: Amount is too small");
  });
});

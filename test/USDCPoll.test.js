const { expect } = require("chai");
const { ethers } = require("hardhat");
var should = require('chai').should()
const {utils, BigNumber} = require('ethers');
const assert = require("chai").assert;
let [singer, user1] = "";
let UsdcPool;
const USDCCount  = 1000;
before("USDCPool", async () => {
  [singer, user1] = await ethers.getSigners();
  // console.log(singer)
  //deploying smart contract .
  // const usdcPool = await ethers.getContractFactory("USDCPool");
  //  UsdcPool = await usdcPool.deploy();
  // await UsdcPool.deployed();

  // working on a specifce deployed address ..
  const Exchange = await ethers.getContractFactory("USDCPool", singer);
  UsdcPool = Exchange.attach("0x2FF3049dCdf75D86b2F584dF13b19D9A3560b378");
  // console.log(UsdcPool.address);
});

function convertToNumber(bigNumber){
  let res = utils.formatEther(bigNumber);
  res = (+res).toFixed(4);
return res;
}
const user_WUSDC_Balanace = async()=>{
  let TotalBalnace = await UsdcPool.callStatic.balanceOf(singer.address);
  TotalBalnace = convertToNumber(TotalBalnace);
  return TotalBalnace;
}
describe("testing Contract functions ..", function() {
  it("provide liquidity", async () => {
    let userBalance =  await user_WUSDC_Balanace();
    console.log(`Total WUSD owns by  ${singer.address}  before the provide tx  - > ${userBalance}`);
    let result = await UsdcPool.connect(singer).provide(USDCCount,{
      value: 0,
    });
    //getting the events.
    const contractReceipt = await result.wait();
    // console.log(contractReceipt)
    let WUSDC = await contractReceipt.events[1].args.value;
    // console.log(WUSDC)
    assert.notEqual(WUSDC, 0);
    assert.notEqual(WUSDC, "");
    assert.notEqual(WUSDC, null);
    assert.notEqual(WUSDC, undefined);
    assert.equal(WUSDC, USDCCount);
    userBalance =  await user_WUSDC_Balanace();
    console.log(`view Provied  Tx -> https://kovan.etherscan.io/tx/${contractReceipt.transactionHash}`)
    console.log(`Total WUSD  owns by ${singer.address}  after the provide tx - > ${userBalance}`);
  });

  it("Total USer balance and withdraw USDC", async () => {
   let userBalance =  await user_WUSDC_Balanace();
    console.log(`Total WUSD  owns by  ${singer.address}  before the withdraw tx  - > ${userBalance}`);

    // withdraw function
    let result = await UsdcPool.connect(singer).withdraw(USDCCount, {
      value: 0,
    });
    const contractReceipt = await result.wait();
    let USDC = await contractReceipt.events[1].args.value
    assert.notEqual(USDC, 0);
    assert.notEqual(USDC, "");
    assert.notEqual(USDC, null);
    assert.notEqual(USDC, undefined);
    console.log('USDC value that user get ',USDC)
    // assert.equal(USDC, USDCCount);
    userBalance =  await user_WUSDC_Balanace();
    console.log(`view withdraw Tx -> https://kovan.etherscan.io/tx/${contractReceipt.transactionHash}`)
    console.log(`Total WUSD owns by  ${singer.address}  after the withdraw tx - > ${userBalance}`);
  });
});

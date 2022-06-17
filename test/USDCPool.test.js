// const { expect } = require("chai");
const { ethers } = require("hardhat");
// var should = require('chai').should()
// const {utils, BigNumber} = require('ethers');
const assert = require("chai").assert;
let [signer, user1] = "";
let usdcPoolContract = null;
const USDCCount  = 1000;
// commenting the console.log which will be removed after the testing of the entire contract is completed
before("USDCPool", async () => {
  [signer, user1] = await ethers.getSigners();
  // console.log(signer)
  //deploying smart contract .
  // const usdcPool = await ethers.getContractFactory("USDCPool");
  //  usdcPoolContract = await usdcPool.deploy();
  // await usdcPoolContract.deployed();

  // working on a specifce deployed address ..
  const Exchange = await ethers.getContractFactory("USDCPool", signer);
  usdcPoolContract = Exchange.attach("0x2FF3049dCdf75D86b2F584dF13b19D9A3560b378");
  // console.log(usdcPoolContract.address);
});

// function convertToNumber(bigNumber){
//   let res = utils.formatEther(bigNumber);
//   res = (+res).toFixed(4);
// return res;
// }
// const user_WUSDC_Balanace = async()=>{
//   let TotalBalnace = await usdcPoolContract.callStatic.balanceOf(signer.address);
//   TotalBalnace = convertToNumber(TotalBalnace);
//   return TotalBalnace;
// }
describe("testing Contract functions ..", function() {
  it("provide liquidity", async () => {
    // let userBalance =  await user_WUSDC_Balanace();
    // console.log(`Total WUSD owns by  ${signer.address}  before the provide tx  - > ${userBalance}`);
    let result = await usdcPoolContract.connect(signer).provide(USDCCount,{
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
    // assert.equal(WUSDC, USDCCount);
    // userBalance =  await user_WUSDC_Balanace();
    // console.log(`view Provied  Tx -> https://kovan.etherscan.io/tx/${contractReceipt.transactionHash}`)
    // console.log(`Total WUSD  owns by ${signer.address}  after the provide tx - > ${userBalance}`);
  });

  it("Total USer balance and withdraw USDC", async () => {
  //  let userBalance =  await user_WUSDC_Balanace();
    // console.log(`Total WUSD  owns by  ${signer.address}  before the withdraw tx  - > ${userBalance}`);

    // withdraw function
    let result = await usdcPoolContract.connect(signer).withdraw(USDCCount, {
      value: 0,
    });
    const contractReceipt = await result.wait();
    let USDC = await contractReceipt.events[1].args.value
    assert.notEqual(USDC, 0);
    assert.notEqual(USDC, "");
    assert.notEqual(USDC, null);
    assert.notEqual(USDC, undefined);
    // console.log('USDC value that user get ',USDC)
    // assert.equal(USDC, USDCCount);
    // userBalance =  await user_WUSDC_Balanace();
    // console.log(`view withdraw Tx -> https://kovan.etherscan.io/tx/${contractReceipt.transactionHash}`)
    // console.log(`Total WUSD owns by  ${signer.address}  after the withdraw tx - > ${userBalance}`);
  });
});

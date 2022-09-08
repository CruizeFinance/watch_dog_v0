import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, Contract } from "ethers";
import hre, { ethers } from "hardhat";
const { utils } = ethers;

function convertToNumber(bigNumber: BigNumber) {
  let res = utils.formatEther(bigNumber);
  res = (+res).toFixed(4);
  return res;
}
describe("testing Contract functions ..", function () {
  let signer: SignerWithAddress;
  let UsdcPool:Contract;
  const USDCCount = 1000;

  before("USDCPool", async () => {
    [signer] = await ethers.getSigners();
    // working on a specifce deployed address ..
    const Exchange = await ethers.getContractFactory("USDCPool", signer);
    UsdcPool = Exchange.attach("0x2FF3049dCdf75D86b2F584dF13b19D9A3560b378");
  });

  it("provide liquidity", async () => {
    let TotalBalnace = await UsdcPool.callStatic.balanceOf(signer.address);
    let userBalance = convertToNumber(TotalBalnace);
    console.log(
      `Total WUSD owns by  ${signer.address}  before the provide tx  - > ${userBalance}`
    );
    let result = await UsdcPool.connect(signer).provide(USDCCount, {
      value: 0,
    });
    //getting the events.
    const contractReceipt = await result.wait();
    let WUSDC = await contractReceipt.events[1].args.value;
    expect(WUSDC).not.equal(0)
    expect(WUSDC).not.equal("")
    expect(WUSDC).not.equal(null)
    expect(WUSDC).not.equal(undefined)
    expect(WUSDC).to.be.equal(USDCCount)

    TotalBalnace = await UsdcPool.callStatic.balanceOf(signer.address);
    userBalance = convertToNumber(TotalBalnace);

    console.log(
      `view Provied  Tx -> https://kovan.etherscan.io/tx/${contractReceipt.transactionHash}`
    );
    console.log(
      `Total WUSD  owns by ${signer.address}  after the provide tx - > ${userBalance}`
    );
  });

  it("Total USer balance and withdraw USDC", async () => {
    let TotalBalnace = await UsdcPool.callStatic.balanceOf(signer.address);
    let userBalance = convertToNumber(TotalBalnace);
    console.log(
      `Total WUSD  owns by  ${signer.address}  before the withdraw tx  - > ${userBalance}`
    );

    // withdraw function
    let result = await UsdcPool.connect(signer).withdraw(USDCCount, {
      value: 0,
    });
    const contractReceipt = await result.wait();
    let USDC = await contractReceipt.events[1].args.value;

    expect(USDC).not.equal(0)
    expect(USDC).not.equal("")
    expect(USDC).not.equal(null)
    expect(USDC).not.equal(undefined)
    console.log("USDC value that user get ", USDC);
    TotalBalnace = await UsdcPool.callStatic.balanceOf(signer.address);
    userBalance= convertToNumber(TotalBalnace);
    console.log(
      `view withdraw Tx -> https://kovan.etherscan.io/tx/${contractReceipt.transactionHash}`
    );
    console.log(
      `Total WUSD owns by  ${signer.address}  after the withdraw tx - > ${userBalance}`
    );
  });
});

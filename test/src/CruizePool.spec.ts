import { expect } from "chai";
import { Contract, Signer } from "ethers";
import { parseEther } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";

import { getTime,increaseTime } from "../utils/utilities";

describe("Cruize Protocol", function () {

  let deployer: Signer;
  let user: Signer;

  let poolInstance: Contract;
  let usdcInstance: Contract;


  before(async () => {
    [deployer, user] = await ethers.getSigners();

    const USDCToken = await ethers.getContractFactory("USDC", deployer);
    const USDCPool = await ethers.getContractFactory("USDCPool", deployer);

    usdcInstance = await USDCToken.deploy();
    poolInstance = await USDCPool.deploy(usdcInstance.address);

    hre.tracer.nameTags[await deployer.getAddress()] = "ADMIN";
    hre.tracer.nameTags[await usdcInstance.address] = "USDC";
    hre.tracer.nameTags[await poolInstance.address] = "USDC POOL";
  });

  it("Deposit usdc tokens to get lp tokens", async function () {
    await usdcInstance.approve(poolInstance.address, parseEther("10000"));

    await expect(() => poolInstance.deposit(parseEther("100")))
    .changeTokenBalance(usdcInstance,poolInstance,parseEther("100"))
    // await poolInstance.deposit(parseEther("100"));
  })

  it("Withdraw usdc tokens from pool", async function () {
    await increaseTime(1296000)
    await expect(() => poolInstance.withdraw(parseEther("100")))
    .changeTokenBalance(usdcInstance,deployer,parseEther("100"))
  })

});

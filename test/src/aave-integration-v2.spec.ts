import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Contract, BigNumber } from "ethers";
import { formatUnits, parseEther, parseUnits } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";

import { Impersonate } from "../utils/utilities";

describe.only("Aave Integration V2", function () {
  let signer: SignerWithAddress;
  let wrapper: Contract;
  let wethGateway: Contract;
  let token: Contract;
  let pool: Contract;
  let usdcAccount: SignerWithAddress;

  let borrowAmount: BigNumber;

  let usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  let weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let usdcHolder = "0x72A53cDBBcc1b9efa39c834A540550e23463AAcB";

  before(async () => {
    [signer] = await ethers.getSigners();
    usdcAccount = await Impersonate(usdcHolder);

    const AaveWrapper = await ethers.getContractFactory("AaveWrapper", usdcAccount);


    token = await ethers.getContractAt("IERC20", usdc, signer);
    wrapper = await AaveWrapper.deploy();

    pool = await ethers.getContractAt(
      "IPoolV2",
      "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9",
      signer
    );
    wethGateway = await ethers.getContractAt(
      "IWETHGateway",
      "0xcc9a0B7c43DC2a5F023Bb9b738E45B0Ef6B06E04",
      signer
    );

    hre.tracer.nameTags[pool.address] = "POOL";
    hre.tracer.nameTags[signer.address] = "ADMIN";
    hre.tracer.nameTags[wrapper.address] = "TEST-TOKEN";
    hre.tracer.nameTags[usdcAccount.address] = "USDC-HOLDER";
    hre.tracer.nameTags[wethGateway.address] = "WETHGateway";

    await token.connect(usdcAccount).transfer(wrapper.address,BigNumber.from("100000000"))
  });

  it("ETH Supply", async function () {

    await wrapper.addDepositAsset(
      weth, // WETH
      "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419"
    )


    await wrapper.deposit(weth,parseEther("0"), {
      value: parseEther("10"),
    }); // 1
    
    const data = await pool.callStatic.getReserveData(weth);
    const aToken = await ethers.getContractAt(
      "IERC20",
      data.aTokenAddress,
      signer
      );
      const dToken = await ethers.getContractAt(
        "IERC20",
        data.variableDebtTokenAddress,
        signer
        );
    console.log(await pool.callStatic.getUserAccountData(wrapper.address))
    console.log({
      usdc: await token.callStatic.balanceOf(wrapper.address),
      aWeth: await aToken.callStatic.balanceOf(wrapper.address),
      debtWeth: await dToken.callStatic.balanceOf(wrapper.address),
    });
  });

  it("Borrow USDC", async function () {
    await wrapper
      .borrow(weth);
    
      const data = await pool.callStatic.getReserveData(weth);
    const aToken = await ethers.getContractAt(
      "IERC20",
      data.aTokenAddress,
      signer
      );
      const dToken = await ethers.getContractAt(
        "IERC20",
        data.variableDebtTokenAddress,
        signer
        );
    console.log(await pool.callStatic.getUserAccountData(wrapper.address))
    console.log({
      usdc: await token.callStatic.balanceOf(wrapper.address),
      aWeth: await aToken.callStatic.balanceOf(wrapper.address),
      debtWeth: await dToken.callStatic.balanceOf(wrapper.address),
    });
  });

  it("Repay USDC", async function () {
    await wrapper
    .repay();
  });

  it("Withdraw Eth", async function () {
    const data = await pool.callStatic.getReserveData(weth);
    const aToken = await ethers.getContractAt(
      "IERC20",
      data.aTokenAddress,
      signer
      );
      const dToken = await ethers.getContractAt(
        "IERC20",
        data.variableDebtTokenAddress,
        signer
        );
    console.log(await pool.callStatic.getUserAccountData(wrapper.address))
    console.log({
      usdc: await token.callStatic.balanceOf(wrapper.address),
      aWeth: await aToken.callStatic.balanceOf(wrapper.address),
      debtWeth: await dToken.callStatic.balanceOf(wrapper.address),
    });

    await wrapper
    .withdraw(weth);
  });

});
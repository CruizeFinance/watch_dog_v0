import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Contract, BigNumber } from "ethers";
import { formatUnits, parseEther, parseUnits } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";

import { Impersonate } from "../utils/utilities";

describe("Test Token", function () {
  let signer: SignerWithAddress;
  let wrapper: Contract;
  let wethGateway: Contract;
  let token: Contract;
  let pool: Contract;
  let usdcAccount: SignerWithAddress;

  let borrowAmount: BigNumber;

  let usdc = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607";
  let weth = "0x4200000000000000000000000000000000000006";
  let usdcHolder = "0xa3f45e619cE3AAe2Fa5f8244439a66B203b78bCc";

  const MAX =  BigNumber.from(
    "115792089237316195423570985008687907853269984665640564039457584007913129639935"
  )

  before(async () => {
    [signer] = await ethers.getSigners();
    usdcAccount = await Impersonate(usdcHolder);

    const AaveWrapper = await ethers.getContractFactory("AaveWrapper", usdcAccount);
    token = await ethers.getContractAt("IERC20", usdc, usdcAccount);
    wrapper = await AaveWrapper.deploy();

    pool = await ethers.getContractAt(
      "IPoolV3",
      "0x794a61358D6845594F94dc1DB02A252b5b4814aD",
      usdcAccount
    );
    wethGateway = await ethers.getContractAt(
      "IWETHGateway",
      "0x86b4D2636EC473AC4A5dD83Fc2BEDa98845249A7",
      usdcAccount
    );

    hre.tracer.nameTags[signer.address] = "ADMIN";
    hre.tracer.nameTags[wrapper.address] = "TEST-TOKEN";
    hre.tracer.nameTags[usdcAccount.address] = "USDC-HOLDER";
  });

  it("ETH Supply", async function () {

    // Supply 1 ETH as a collateral so we can borrow usdc
    await wethGateway.depositETH(pool.address, usdcAccount.address, "0", {
      value: parseEther("1"),
    });

    const data = await pool.callStatic.getReserveData(weth);
    const aToken = await ethers.getContractAt(
      "IERC20",
      data.aTokenAddress,
      usdcAccount
    );
    const dToken = await ethers.getContractAt(
      "IERC20",
      data.variableDebtTokenAddress,
      usdcAccount
    );
    console.log({
      usdc: await token.callStatic.balanceOf(usdcAccount.address),
      aWeth: await aToken.callStatic.balanceOf(usdcAccount.address),
      debtWeth: await dToken.callStatic.balanceOf(usdcAccount.address),
    });
  });

  it("Borrow USDC", async function () {
    const userData = await pool.callStatic.getUserAccountData(usdcAccount.address);

    // Here we are borrowing 20% USDC of the total borrow available(in usd ) against our collateral
    borrowAmount = userData.availableBorrowsBase
      .mul(BigNumber.from("20"))
      .div(BigNumber.from("10000"));
    await pool
      .connect(usdcAccount)
      .borrow(usdc, borrowAmount, "2", "0", usdcAccount.address);

    console.log(await pool.callStatic.getUserAccountData(usdcAccount.address));

    const wethData = await pool.callStatic.getReserveData(weth);
    const usdcData = await pool.callStatic.getReserveData(usdc);
    const aToken = await ethers.getContractAt(
      "IERC20",
      wethData.aTokenAddress,
      usdcAccount
    );

    const aUSDCToken = await ethers.getContractAt(
      "IERC20",
      usdcData.aTokenAddress,
      usdcAccount
    );

    const dUSDCToken = await ethers.getContractAt(
      "IERC20",
      usdcData.variableDebtTokenAddress,
      usdcAccount
    );

    const dToken = await ethers.getContractAt(
      "IERC20",
      wethData.variableDebtTokenAddress,
      usdcAccount
    );
    console.log({
      usdc: await token.callStatic.balanceOf(usdcAccount.address),
      aUSDC: await aUSDCToken.callStatic.balanceOf(usdcAccount.address),
      vUSDC: await dUSDCToken.callStatic.balanceOf(usdcAccount.address),
      aWeth: await aToken.callStatic.balanceOf(usdcAccount.address),
      debtWeth: await dToken.callStatic.balanceOf(usdcAccount.address),
    });
  });

  it("Repay USDC", async function () {
    console.log(await pool.callStatic.getUserAccountData(usdcAccount.address))

    // Approving the USC's to the pool so we can repay the borrowed USDC amount
    await token.approve(
      pool.address,
      MAX
    );
      
    const wethData = await pool.callStatic.getReserveData(weth);
    const usdcData = await pool.callStatic.getReserveData(usdc);

    // Here we passed the MAX amount so that we can repay all debt amount in USDC
    await pool.connect(usdcAccount).repay(usdc, MAX, "2",usdcAccount.address);

    const aToken = await ethers.getContractAt(
      "IERC20",
      wethData.aTokenAddress,
      usdcAccount
    );

    const aUSDCToken = await ethers.getContractAt(
      "IERC20",
      usdcData.aTokenAddress,
      usdcAccount
    );

    const dUSDCToken = await ethers.getContractAt(
      "IERC20",
      usdcData.variableDebtTokenAddress,
      usdcAccount
    );

    const dToken = await ethers.getContractAt(
      "IERC20",
      wethData.variableDebtTokenAddress,
      usdcAccount
    );
    console.log({
      usdc: await token.callStatic.balanceOf(usdcAccount.address),
      aUSDC: await aUSDCToken.callStatic.balanceOf(usdcAccount.address),
      vUSDC: await dUSDCToken.callStatic.balanceOf(usdcAccount.address),
      aWeth: await aToken.callStatic.balanceOf(usdcAccount.address),
      debtWeth: await dToken.callStatic.balanceOf(usdcAccount.address),
    });

  });

  it("Withdraw Eth", async function () {

    // Here we are pass MAX as a withdrawal amount so that we can withdraw all deposited collateral
    await pool.withdraw(weth,MAX,usdcAccount.address)
    
    console.log(await pool.callStatic.getUserAccountData(usdcAccount.address))
    const wethData = await pool.callStatic.getReserveData(weth);
    const usdcData = await pool.callStatic.getReserveData(usdc);
    const aToken = await ethers.getContractAt(
      "IERC20",
      wethData.aTokenAddress,
      usdcAccount
    );

    const aUSDCToken = await ethers.getContractAt(
      "IERC20",
      usdcData.aTokenAddress,
      usdcAccount
    );

    const dUSDCToken = await ethers.getContractAt(
      "IERC20",
      usdcData.variableDebtTokenAddress,
      usdcAccount
    );

    const dToken = await ethers.getContractAt(
      "IERC20",
      wethData.variableDebtTokenAddress,
      usdcAccount
    );
    console.log({
      usdc: await token.callStatic.balanceOf(usdcAccount.address),
      aUSDC: await aUSDCToken.callStatic.balanceOf(usdcAccount.address),
      vUSDC: await dUSDCToken.callStatic.balanceOf(usdcAccount.address),
      aWeth: await aToken.callStatic.balanceOf(usdcAccount.address),
      debtWeth: await dToken.callStatic.balanceOf(usdcAccount.address),
    });
  });
});
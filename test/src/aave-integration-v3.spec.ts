import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Contract, BigNumber } from "ethers";
import { formatUnits, parseEther, parseUnits } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";

import { Impersonate } from "../utils/utilities";


describe("Aave Integration V3", function () {

  let signer: SignerWithAddress;
  let wrapper: Contract;
  let wethGateway: Contract;
  let token: Contract;
  let pool: Contract;
  let usdcAccount: SignerWithAddress;

  let borrowAmount: BigNumber;


  let usdc = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8";
  let weth = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
  let usdcHolder = "0x1714400FF23dB4aF24F9fd64e7039e6597f18C2b";


  before(async () => {
    [signer] = await ethers.getSigners();
    usdcAccount = await Impersonate(usdcHolder);


    const AaveWrapper = await ethers.getContractFactory("AaveV3Wrapper", usdcAccount);


    token = await ethers.getContractAt("IERC20", usdc, signer);

    wrapper = await AaveWrapper.deploy();

    pool = await ethers.getContractAt(
      "IPoolV3",
      "0x794a61358D6845594F94dc1DB02A252b5b4814aD",

      signer
    );
    wethGateway = await ethers.getContractAt(
      "IWETHGateway",
      "0xC09e69E79106861dF5d289dA88349f10e2dc6b5C",
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
      "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612"
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
    // console.log(await pool.callStatic.getUserAccountData(wrapper.address))
    // console.log({
    //   usdc: await token.callStatic.balanceOf(wrapper.address),
    //   aWeth: await aToken.callStatic.balanceOf(wrapper.address),
    //   debtWeth: await dToken.callStatic.balanceOf(wrapper.address),

    // });
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
    // console.log(await pool.callStatic.getUserAccountData(wrapper.address))
    // console.log({
    //   usdc: await token.callStatic.balanceOf(wrapper.address),
    //   aWeth: await aToken.callStatic.balanceOf(wrapper.address),
    //   debtWeth: await dToken.callStatic.balanceOf(wrapper.address),

    // });
  });

  it("Repay USDC", async function () {

    await wrapper
    .repay("100000000");
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
const { expect } = require("chai");
const { parseEther } = require("ethers/lib/utils");
const { ethers } = require("hardhat");
const assert = require("chai").assert;

// only is used for runing single test file
describe("TESTING FOR ETH (NATIVE ETH)", function() {
  let signer;
  let user1;
  let WETHcontract;
  let assetPoolContract;

  before(async () => {
    [signer, user1] = await ethers.getSigners();

    const ERC20Token = await ethers.getContractFactory(
      "CRTokenUpgradeable",
      signer
    );
    const ERC20 = await ERC20Token.deploy();

    const assetContract = await ethers.getContractFactory(
      "AssetPoolUpgradeable",
      signer
    );
    assetPoolContract = await assetContract.deploy();

    await assetPoolContract.initialize(ERC20.address);
    //approving USDC to spend .
    const usdcCoin = await ethers.getContractFactory(
      "CRTokenUpgradeable",
      signer
    );
    let USDCCoin = usdcCoin.attach(
      "0xb7a4F3E9097C08dA09517b5aB877F7a917224ede"
    );
    await USDCCoin.approve(
      assetPoolContract.address,
      ethers.utils.parseEther("2000000")
    );

    hre.tracer.nameTags[await signer.getAddress()] = "ADMIN";
    hre.tracer.nameTags[ERC20.address] = "CRTOKEN";
    hre.tracer.nameTags[assetPoolContract.address] = "ASSET POOL CONTRACT";
  });
  it.only("Create CRETH", async () => {
    await expect(
      assetPoolContract.createToken(
        "Cruize ETH",
        "CRETH",
        "0xd0A1E359811322d97991E03f863a0C30C2cF029C",
        18
      )
    ).to.emit(assetPoolContract, "CreateToken");

    //checking for the owner of the token
    const CRETHtoken = await assetPoolContract.lpTokens(
      "0xd0A1E359811322d97991E03f863a0C30C2cF029C"
    );
    const CRETH = await ethers.getContractFactory("CRTokenUpgradeable", signer);
    let CRETHcontract = CRETH.attach(CRETHtoken);
    const CRETHTokenOwner = await CRETHcontract.owner();
    assert.equal(CRETHTokenOwner, assetPoolContract.address);
  });
  it.only("Revert, if token name is an empty string", async () => {
    await expect(
      assetPoolContract.createToken(
        "",
        "SYM",
        "0xE0E24a32A7e50Ea1c7881c54bfC1934e9b50B520",
        18
      )
    ).to.be.revertedWith("EMPTY_NAME");
  });

  it.only("Revert, if token symbol is an empty string", async () => {
    await expect(
      assetPoolContract.createToken(
        "CR Token",
        "",
        "0xE0E24a32A7e50Ea1c7881c54bfC1934e9b50B520",
        18
      )
    ).to.be.revertedWith("EMPTY_SYMBOL");
  });

  it.only("Revert, if amount != msg.value", async () => {
    await expect(
      assetPoolContract.depositAsset(
        ethers.utils.parseEther("1"),
        "0xd0A1E359811322d97991E03f863a0C30C2cF029C",
        { value: ethers.utils.parseEther("0") }
      )
    ).to.be.revertedWith("NOT_MATCHED");
  });

  it.only("Revert, if reserve address is not exist", async () => {
    await expect(
      assetPoolContract.depositAsset(
        ethers.utils.parseEther("1"),
        "0xE0E24a32A7e50Ea1c7881c54bfC1934e9b50B520",
        { value: ethers.utils.parseEther("0") }
      )
    ).to.be.revertedWith("NOT_ALLOWED");
  });

  it.only("Revert, if reserve address is a zero address", async () => {
    await expect(
      assetPoolContract.depositAsset(
        ethers.utils.parseEther("1"),
        "0x0000000000000000000000000000000000000000",
        { value: ethers.utils.parseEther("0") }
      )
    ).to.be.revertedWith("ZERO_ADDRESS");
  });

  it.only("Successfully Deposit ETH", async () => {
    await expect(
      assetPoolContract.depositAsset(
        ethers.utils.parseEther("1"),
        "0xd0A1E359811322d97991E03f863a0C30C2cF029C",
        { value: ethers.utils.parseEther("1") }
      )
    )
      .to.emit(assetPoolContract, "DepositEvent")
      .withArgs(await signer.getAddress(), parseEther("1"));
  });
  //WITHDRAW WETH...

  it.only("Revert, If user doesn't have enough crTokens", async () => {
    await expect(
      assetPoolContract
      .withdrawAsset(
        ethers.utils.parseEther("10"),
        "0xd0A1E359811322d97991E03f863a0C30C2cF029C"
      )
    )
      .to.be.revertedWith("NOT_ENOUGH_BALANCE")
  });

  it.only("Revert, If user doesn't have enough crTokens", async () => {
    await expect(
      assetPoolContract
      .withdrawAsset(
        ethers.utils.parseEther("0"),
        "0xE0E24a32A7e50Ea1c7881c54bfC1934e9b50B520"
      )
    )
      .to.be.revertedWith("ZERO_AMOUNT")
  });

  it.only("Revert, If token address is zero address", async () => {
    await expect(
      assetPoolContract
      .withdrawAsset(
        ethers.utils.parseEther("1"),
        "0x0000000000000000000000000000000000000000"
      )
    )
      .to.be.revertedWith("ZERO_ADDRESS")
  });

  it.only("Withdraw ETH", async () => {
    await expect(assetPoolContract.withdrawAsset(
      ethers.utils.parseEther("1"),
      "0xd0A1E359811322d97991E03f863a0C30C2cF029C"
    ))
      .to.emit(assetPoolContract,"WithdrawEvent")
      .withArgs(await signer.getAddress(),parseEther("1"))
  });

  // ------------Testing for Other WTokens------------

  it.only("Create CRUSDC", async () => {
    await expect(assetPoolContract.createToken(
      "Cruize USDC",
      "CRUSDC",
      "0xb7a4F3E9097C08dA09517b5aB877F7a917224ede",
      6
    )).to.emit(assetPoolContract,"CreateToken")


  });

  it.only("Deposit USDC", async () => {
    await expect(assetPoolContract.depositAsset(
      10000000,
      "0xb7a4F3E9097C08dA09517b5aB877F7a917224ede"
    )).not.reverted;
  });

  //WITHDRAW WETH...
  it.only("Withdraw USDC", async () => {
     await expect(assetPoolContract.withdrawAsset(
      1000000,
      "0xb7a4F3E9097C08dA09517b5aB877F7a917224ede"
    )).not.reverted
  });

});

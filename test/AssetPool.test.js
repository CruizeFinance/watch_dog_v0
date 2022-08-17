const { FallbackProvider } = require("@ethersproject/providers");
const { expect } = require("chai");
const { parseEther } = require("ethers/lib/utils");
const { ethers } = require("hardhat");
const assert = require("chai").assert;
//CONSTANT
const USER_WALLET_ADDRESS = "0xE0E24a32A7e50Ea1c7881c54bfC1934e9b50B520";
const USDSC_CONTRACT_ADDRESS = "0xb7a4F3E9097C08dA09517b5aB877F7a917224ede";
const WETH_CONTRACT_ADDRESS = "0xd0A1E359811322d97991E03f863a0C30C2cF029C";
const NULL_ADDRESS = "0x0000000000000000000000000000000000000000";
const ERC20_DECIMAL_VALUE = 18;
//loading contracts ..
const loadAndDeployContract = async (factoryName, signer) => {
  const contractFactory = await ethers.getContractFactory(factoryName, signer);
  return await contractFactory.deploy();
};
//loading contracts and approving amount ..
const loadContractAndApprove = async (
  factoryName,
  contractAddress,
  approvalamount,
  foraddress,
  signer
) => {
  const contractFactory = await ethers.getContractFactory(factoryName, signer);
  const token = await contractFactory.attach(contractAddress);
  await token.approve(foraddress, ethers.utils.parseEther(approvalamount));
};
describe("TESTING FOR ETH (NATIVE ETH)", function() {
  let signer;
  let user1;
  let assetPoolContract;

  before(async () => {
    [signer, user1] = await ethers.getSigners();
    const ERC20 = await loadAndDeployContract("CRTokenUpgradeable", signer);
    assetPoolContract = await loadAndDeployContract(
      "AssetPoolUpgradeable",
      signer
    );
    await assetPoolContract.initialize(ERC20.address);
    await loadContractAndApprove(
      "CRTokenUpgradeable",
      USDSC_CONTRACT_ADDRESS,
      "2000000",
      assetPoolContract.address,
      signer
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
        WETH_CONTRACT_ADDRESS,
        ERC20_DECIMAL_VALUE
      )
    ).to.emit(assetPoolContract, "CreateToken");

    //checking for the owner of the token
    const CRETHtoken = await assetPoolContract.lpTokens(WETH_CONTRACT_ADDRESS);
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
        USER_WALLET_ADDRESS,
        ERC20_DECIMAL_VALUE
      )
    ).to.be.revertedWith("EMPTY_NAME");
  });

  it.only("Revert, if token symbol is an empty string", async () => {
    await expect(
      assetPoolContract.createToken(
        "CR Token",
        "",
        USER_WALLET_ADDRESS,
        ERC20_DECIMAL_VALUE
      )
    ).to.be.revertedWith("EMPTY_SYMBOL");
  });

  it.only("Revert, if amount != msg.value", async () => {
    await expect(
      assetPoolContract.depositAsset(
        ethers.utils.parseEther("1"),
        WETH_CONTRACT_ADDRESS,
        { value: ethers.utils.parseEther("0") }
      )
    ).to.be.revertedWith("NOT_MATCHED");
  });

  it.only("Revert, if reserve address is not exist", async () => {
    await expect(
      assetPoolContract.depositAsset(
        ethers.utils.parseEther("1"),
        USER_WALLET_ADDRESS,
        { value: ethers.utils.parseEther("0") }
      )
    ).to.be.revertedWith("NOT_ALLOWED");
  });

  it.only("Revert, if reserve address is a zero address", async () => {
    await expect(
      assetPoolContract.depositAsset(
        ethers.utils.parseEther("1"),
        NULL_ADDRESS,
        { value: ethers.utils.parseEther("0") }
      )
    ).to.be.revertedWith("ZERO_ADDRESS");
  });

  it.only("Successfully Deposit ETH", async () => {
    await expect(
      assetPoolContract.depositAsset(
        ethers.utils.parseEther("1"),
        WETH_CONTRACT_ADDRESS,
        { value: ethers.utils.parseEther("1") }
      )
    )
      .to.emit(assetPoolContract, "DepositEvent")
      .withArgs(await signer.getAddress(), parseEther("1"));
  });
  //WITHDRAW WETH...

  it.only("Revert, If user doesn't have enough crTokens", async () => {
    await expect(
      assetPoolContract.withdrawAsset(
        ethers.utils.parseEther("10"),
        WETH_CONTRACT_ADDRESS
      )
    ).to.be.revertedWith("NOT_ENOUGH_BALANCE");
  });

  it.only("Revert, If user doesn't have enough crTokens", async () => {
    await expect(
      assetPoolContract.withdrawAsset(
        ethers.utils.parseEther("0"),
        USER_WALLET_ADDRESS
      )
    ).to.be.revertedWith("ZERO_AMOUNT");
  });

  it.only("Revert, If token address is zero address", async () => {
    await expect(
      assetPoolContract.withdrawAsset(
        ethers.utils.parseEther("1"),
        NULL_ADDRESS
      )
    ).to.be.revertedWith("ZERO_ADDRESS");
  });

  it.only("Withdraw ETH", async () => {
    await expect(
      assetPoolContract.withdrawAsset(
        ethers.utils.parseEther("1"),
        WETH_CONTRACT_ADDRESS
      )
    )
      .to.emit(assetPoolContract, "WithdrawEvent")
      .withArgs(await signer.getAddress(), parseEther("1"));
  });

  // ------------Testing for Other WTokens------------

  it.only("Create CRUSDC", async () => {
    await expect(
      assetPoolContract.createToken(
        "Cruize USDC",
        "CRUSDC",
        USDSC_CONTRACT_ADDRESS,
        6
      )
    ).to.emit(assetPoolContract, "CreateToken");
  });

  it.only("Deposit USDC", async () => {
    await expect(
      assetPoolContract.depositAsset(10000000, USDSC_CONTRACT_ADDRESS)
    ).not.reverted;
  });

  //WITHDRAW WETH...
  it.only("Withdraw USDC", async () => {
    await expect(
      assetPoolContract.withdrawAsset(1000000, USDSC_CONTRACT_ADDRESS)
    ).not.reverted;
  });
});

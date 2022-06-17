
const { ethers } = require("hardhat");
const assert = require("chai").assert;
const should = require("chai").should;
let [signer, user1] = "";
var chai = require("chai");
var chaiAsPromised = require("chai-as-promised");
const { util } = require("chai");
let assetPoolContract = null;
let WETHcontract = null;
before("AssetPool", async () => {
  [signer, user1] = await ethers.getSigners();
  // working on a specifc deployed address ..
  // const Exchange = await ethers.getContractFactory('AssetPool', signer)
  // assetPoolContract = Exchange.attach(
  //   '0xD73B517dd0555d0F87dffB2D1fF67A23986112ba',
  // )

  const ERC20Token = await ethers.getContractFactory(
    "CRTokenUpgradeable",
    signer
  );
  const ERC20 = await ERC20Token.deploy();
  const assetContract = await ethers.getContractFactory("AssetPoolUpgradeable", signer);
  assetPoolContract = await assetContract.deploy();
  await assetPoolContract.initialize(ERC20.address);
//approving USDC to spend .
  const usdcCoin = await ethers.getContractFactory("CRTokenUpgradeable", signer);
  let USDCCoin =  usdcCoin.attach("0xb7a4F3E9097C08dA09517b5aB877F7a917224ede");
  await USDCCoin.approve(assetPoolContract.address,ethers.utils.parseEther("2000000"));

  hre.tracer.nameTags[await signer.getAddress()] = "ADMIN";
  hre.tracer.nameTags[ERC20.address] = "CRTOKEN";
  hre.tracer.nameTags[assetPoolContract.address] = "ASSET POOL CONTRACT";
});
// only is used for runing single test file
describe("TESTING FOR ETH (NATIVE ETH)", function() {
  it.only("Create CRETH", async () => {
    let result = await assetPoolContract.createToken(
      "Cruize ETH",
      "CRETH",
      "0xd0A1E359811322d97991E03f863a0C30C2cF029C",
      18
    );
    //checking for the owner of the token 
    const CRETHtoken =  await assetPoolContract.lpTokens("0xd0A1E359811322d97991E03f863a0C30C2cF029C");
    const CRETH = await ethers.getContractFactory("CRTokenUpgradeable", signer);
    let CRETHcontract =  CRETH.attach(CRETHtoken);
    const CRETHTokenOwner =  await CRETHcontract.owner();
    assert.equal(CRETHTokenOwner,assetPoolContract.address);


    assetPoolContract
      .createToken("", "", "0xE0E24a32A7e50Ea1c7881c54bfC1934e9b50B520", 18)
      .then((result) => {
        result.should.be.rejectedWith("1:name could not be empty string");
      });
  });
  it.only("Deposit ETH", async () => {
    let result = await assetPoolContract.depositAsset(
      ethers.utils.parseEther("1"),
      "0xd0A1E359811322d97991E03f863a0C30C2cF029C",
      { value: ethers.utils.parseEther("1") }
    );

    // should reject becuase the  ether's value is 0

    assetPoolContract
      .depositAsset(
        ethers.utils.parseEther("1"),
        "0xd0A1E359811322d97991E03f863a0C30C2cF029C",
        { value: ethers.utils.parseEther("0") }
      )
      .then((result) => {
        result.should.be.rejectedWith("1:msg value cannot less then amount");
      });

    /*should be reject becuase this is not an asset address that is allowd by the CRUIZE */

    assetPoolContract
      .depositAsset(
        ethers.utils.parseEther("1"),
        "0xE0E24a32A7e50Ea1c7881c54bfC1934e9b50B520",
        { value: ethers.utils.parseEther("0") }
      )
      .then((result) => {
        result.should.be.rejectedWith("1: Cannot diposit unallowed asset.");
        console.log(result);
      });

    //should be rejected becuase the token address is null.

    assetPoolContract
      .depositAsset(
        ethers.utils.parseEther("1"),
        "0x0000000000000000000000000000000000000000",
        { value: ethers.utils.parseEther("0") }
      )
      .then((result) => {
        result.should.be.rejectedWith("1: Cannot diposit unallowed asset.");
        console.log(result);
      });
  });
  //WITHDRAW WETH...
  it.only("Withdraw ETH", async () => {
    // console.log(
    //   "user balance ",
    //   ethers.utils.formatUnits(await signer.getBalance(), "ether")
    // );
    let result = await assetPoolContract.withdrawAsset(
      ethers.utils.parseEther("1"),
      "0xd0A1E359811322d97991E03f863a0C30C2cF029C"
    );
    // should reject becuase the  ether's value is > then the user's balance.

    assetPoolContract
      .withdrawAsset(
        ethers.utils.parseEther("10"),
        "0xd0A1E359811322d97991E03f863a0C30C2cF029C"
      )
      .then((result) => {
        result.should.be.rejectedWith("1: Not enough balance");
      });

    /*should be reject becuase the amount is zero. */

    assetPoolContract
      .withdrawAsset(
        ethers.utils.parseEther("0"),
        "0xE0E24a32A7e50Ea1c7881c54bfC1934e9b50B520"
      )
      .then((result) => {
        result.should.be.rejectedWith("1: Amount cannot be zero.");
        console.log(result);
      });

    //should be rejected becuase the token address is null.

    assetPoolContract
      .withdrawAsset(
        ethers.utils.parseEther("1"),
        "0x0000000000000000000000000000000000000000"
      )
      .then((result) => {
        result.should.be.rejectedWith("1:can not withraw for null address");
        console.log(result);
      });
  });
});

//TESTING FOR OTHER WTOKENS

describe("Testing for Other WTokens", async () => {
  it.only("Create CRUSDC", async () => {
    let result = await assetPoolContract.createToken(
      "Cruize USDC",
      "CRUSDC",
      "0xb7a4F3E9097C08dA09517b5aB877F7a917224ede",
      6
    );
  });
  it.only("Deposit USDC", async () => {
    let result = await assetPoolContract.depositAsset(
      10000000,
      "0xb7a4F3E9097C08dA09517b5aB877F7a917224ede"
    );
  });
  //WITHDRAW WETH...
  it.only("Withdraw USDC", async () => {
    let result = await assetPoolContract.withdrawAsset(
      1000000,
      "0xb7a4F3E9097C08dA09517b5aB877F7a917224ede"
    );
  });
});

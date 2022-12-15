import { expect } from "chai";
import * as dotenv from "dotenv";
import { BigNumber, constants, Contract } from "ethers";
import hre, { ethers } from "hardhat";
import { formatUnits, parseEther, parseUnits } from "ethers/lib/utils";
import { Impersonate, increaseTime, setBalanceZero } from "../utils/utilities";
import { Constants } from "../utils/constants";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { setBalance } from "@nomicfoundation/hardhat-network-helpers";

dotenv.config({ path: __dirname + "/../../.env" });

const loadContractAndApprove = async (
  name: string,
  address: string,
  amount: string,
  to: string,
  signer: SignerWithAddress
) => {
  const token = await ethers.getContractAt(name, address, signer);
  await token.approve(to, ethers.utils.parseEther(amount));
};

describe("TESTING FOR ETH (NATIVE ETH)", function () {
  let user0: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let signer: SignerWithAddress;
  let impersonateAccount: SignerWithAddress;
  let weth_holder: SignerWithAddress;
  let btc_holder: SignerWithAddress;
  let link_holder: SignerWithAddress;
  let cruize: Contract;
  let ERC20: Contract;
  let wbtcToken: Contract;
  let wethToken: Contract;
  let usdcToken: Contract;

  before(async () => {
    [signer, user0, user1, user2] = await ethers.getSigners();
    // signer = await Impersonate("0x71323401a728925edBAB9a29412868CA20bF6977");
    impersonateAccount = await Impersonate(Constants.USDC_AND_ETH_HOLDER);
    weth_holder = await Impersonate(Constants.WETH_HOLDER);
    await setBalance(Constants.WETH_HOLDER, parseEther("100"));
    btc_holder = await Impersonate(Constants.BTC_HOLDER);
    link_holder = await Impersonate(Constants.LINK_HOLDER);

    const Master = await ethers.getContractFactory(
      "CRTokenUpgradeable",
      signer
    );
    ERC20 = await Master.deploy();

    lendingPool = await ethers.getContractAt(
      "IPoolV2",
      "0x4bd5643ac6f66a5237E18bfA7d47cF22f1c9F210"
    );
    const AssetPool = await ethers.getContractFactory("CruizeTestnet", signer);
    cruize = await AssetPool.deploy();

    await cruize.initialize(signer.address, ERC20.address);

    wethToken = await ethers.getContractAt(
      "ERC20",
      Constants.WETH_CONTRACT_ADDRESS,
      impersonateAccount
    );

    let aaveOracleAccount = await Impersonate(
      "0x77c45699A715A64A7a7796d5CEe884cf617D5254"
    );
    aaveOracle = await ethers.getContractAt(
      "IAaveOracle",
      Constants.AAVEORACLE,
      aaveOracleAccount
    );

    wbtcToken = await ethers.getContractAt("ERC20", Constants.WBTC, btc_holder);

    usdcToken = await ethers.getContractAt(
      "ERC20",
      Constants.USDSC_CONTRACT_ADDRESS,
      impersonateAccount
    );

    linkToken = await ethers.getContractAt(
      "ERC20",
      "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
      link_holder
    );

    await loadContractAndApprove(
      "ERC20",
      Constants.USDSC_CONTRACT_ADDRESS,
      "2000000",
      cruize.address,
      signer
    );

    hre.tracer.nameTags[Constants.WBTC] = "WBTC";
    hre.tracer.nameTags[user0.address] = "USER-0";
    hre.tracer.nameTags[ERC20.address] = "CRTOKEN";
    hre.tracer.nameTags[Constants.POOL] = "AAVE-POOL";
    hre.tracer.nameTags[signer.address] = "CRUIZE WALLET";
    hre.tracer.nameTags[cruize.address] = "CRUIZE-CONTRACT";
    hre.tracer.nameTags[Constants.UNISWAP_V3_ROUTER] = "ROUTER";
    hre.tracer.nameTags[Constants.WETH_CONTRACT_ADDRESS] = "WETH";
    hre.tracer.nameTags[Constants.USDSC_CONTRACT_ADDRESS] = "USDC";
    hre.tracer.nameTags[Constants.USDC_TEST_ADDRESS] = "USDC-TEST";
    hre.tracer.nameTags[impersonateAccount.address] = "USDC-HOLDER";

    // approve USDC tokens to cruize contract from cruize wallet so at the time of repayment
    // Cruize contract can pull USDC tokens from the cruize wallet and payback the loan + interest.
    // await usdcToken
    //   .connect(signer)
    //   .approve(cruize.address, constants.MaxUint256);

    await wbtcToken
      .connect(signer)
      .approve(cruize.address, constants.MaxUint256);

    await wbtcToken
      .connect(signer)
      .approve(lendingPool.address, constants.MaxUint256);

    await wbtcToken
      .connect(user0)
      .approve(cruize.address, constants.MaxUint256);

    await wethToken
      .connect(signer)
      .approve(cruize.address, constants.MaxUint256);

    await wethToken
      .connect(user0)
      .approve(cruize.address, constants.MaxUint256);

    // Here we are transferring some USDC tokens to the cruize wallet so we can repay
    // loan + interest, currently in our cruize wallet we don't have enough USDC tokens
    // to pay the interest.
    await usdcToken
      .connect(impersonateAccount)
      .transfer(signer.address, "10000000000");

    await usdcToken
      .connect(impersonateAccount)
      .transfer(user0.address, "10000000000");

    // These tokens transferred to the cruize contract to repay the loan in testing environemnt
    // await usdcToken.connect(signer).transfer(cruize.address, "10000000000");

    await wethToken
      .connect(weth_holder)
      .transfer(signer.address, parseEther("10"));

    await wethToken
      .connect(weth_holder)
      .transfer(user0.address, parseEther("10"));

    await wbtcToken.connect(btc_holder).transfer(signer.address, "50000000000");

    await wbtcToken.connect(btc_holder).transfer(user0.address, "50000000000");
  });

  it("Throw, if re-intialize the asset pool contract", async () => {
    expect(cruize.initialize(signer.address, ERC20.address)).to.be.revertedWith(
      "Initializable: contract is already initialized"
    );
  });

});

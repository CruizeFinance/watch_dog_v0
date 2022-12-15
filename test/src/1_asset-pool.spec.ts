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
  let crETH: Contract;
  let crWETH: Contract;
  let crWBTC: Contract;
  let wbtcToken: Contract;
  let wethToken: Contract;
  let usdcToken: Contract;
  let linkToken: Contract;
  let aaveOracle: Contract;
  let lendingPool: Contract;

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

  it("Throw, if asset or oracle addresses are zero addresses", async () => {
    await expect(
      cruize.createToken(
        "Cruize ETH",
        "CRETH",
        Constants.WETH_CONTRACT_ADDRESS,
        Constants.NULL_ADDRESS,
        Constants.ERC20_DECIMAL_VALUE,
        100
      )
    ).to.be.revertedWith("ZeroAddress");

    await expect(
      cruize.createToken(
        "Cruize ETH",
        "CRETH",
        Constants.NULL_ADDRESS,
        Constants.ETH_USD_ORACLE,
        Constants.ERC20_DECIMAL_VALUE,
        100
      )
    ).to.be.revertedWith("ZeroAddress");
  });

  it("Revert, if token name is an empty string", async () => {
    await expect(
      cruize.createToken(
        "",
        "SYM",
        Constants.WETH_CONTRACT_ADDRESS,
        Constants.ETH_USD_ORACLE,
        Constants.ERC20_DECIMAL_VALUE,
        100
      )
    ).to.be.revertedWith("EmptyName");
  });

  it("Revert, if token symbol is an empty string", async () => {
    await expect(
      cruize.createToken(
        "CR Token",
        "",
        Constants.WETH_CONTRACT_ADDRESS,
        Constants.ETH_USD_ORACLE,
        Constants.ERC20_DECIMAL_VALUE,
        100
      )
    ).to.be.revertedWith("EmptySymbol");
  });

  it("Create CRETH", async () => {
    await expect(
      cruize.createToken(
        "Cruize ETH",
        "crETH",
        Constants.ETH_ADDRESS,
        Constants.ETH_USD_ORACLE, // ETH-USD oracle address
        Constants.ERC20_DECIMAL_VALUE,
        100
      )
    ).to.emit(cruize, "CreateTokenEvent");

    //checking for the owner of the token
    const CRETHtoken = await cruize.crTokens(Constants.ETH_ADDRESS);
    hre.tracer.nameTags[CRETHtoken] = "CRETH-TOKEN";

    crETH = await ethers.getContractAt(
      "CRTokenUpgradeable",
      CRETHtoken,
      signer
    );
    const CRETHTokenOwner = await crETH.owner();
    expect(CRETHTokenOwner).to.be.equal(cruize.address);

    await expect(
      cruize.createToken(
        "Cruize ETH",
        "CRETH",
        Constants.ETH_ADDRESS,
        Constants.ETH_USD_ORACLE, // ETH-USD oracle address
        Constants.ERC20_DECIMAL_VALUE,
        100
      )
    ).to.be.revertedWith("AssetAlreadyExists");
  });

  it.only("Create CRWETH", async () => {
    await expect(
      cruize.createToken(
        "Cruize WETH",
        "crWETH",
        Constants.WETH_CONTRACT_ADDRESS,
        Constants.ETH_USD_ORACLE, // ETH-USD oracle address
        Constants.ERC20_DECIMAL_VALUE,
        100
      )
    ).to.emit(cruize, "CreateTokenEvent");

    //checking for the owner of the token
    const CRWETHtoken = await cruize.crTokens(Constants.WETH_CONTRACT_ADDRESS);
    hre.tracer.nameTags[CRWETHtoken] = "CRETH-TOKEN";

    crWETH = await ethers.getContractAt("ERC20", CRWETHtoken, weth_holder);

    await expect(
      cruize.createToken(
        "Cruize WETH",
        "CRWETH",
        Constants.WETH_CONTRACT_ADDRESS,
        Constants.ETH_USD_ORACLE, // ETH-USD oracle address
        Constants.ERC20_DECIMAL_VALUE,
        100
      )
    ).to.be.revertedWith("AssetAlreadyExists");
  });

  it.only("Create wBTC", async () => {
    await expect(
      cruize.createToken(
        "Cruize WBTC",
        "crWBTC",
        Constants.WBTC,
        Constants.WBTC_USD_ORACLE, // BTC-USD oracle address
        8,
        3000
      )
    ).to.emit(cruize, "CreateTokenEvent");

    //checking for the owner of the token
    const crWBTCtoken = await cruize.crTokens(Constants.WBTC);
    hre.tracer.nameTags[crWBTCtoken] = "crWBTC-TOKEN";

    crWBTC = await ethers.getContractAt("ERC20", crWBTCtoken, weth_holder);
    await expect(
      cruize.createToken(
        "Cruize WBTC",
        "crWBTC",
        Constants.WBTC,
        Constants.WBTC_USD_ORACLE, // BTC-USD oracle address
        8,
        3000
      )
    ).to.be.revertedWith("AssetAlreadyExists");
  });

  it("Revert, if amount is zero", async () => {
    await expect(
      cruize.deposit("0", Constants.WETH_CONTRACT_ADDRESS, {
        value: ethers.utils.parseEther("0"),
      })
    ).to.be.revertedWith("ZeroAmount");
  });

  it("Revert, if reserve address is zero address", async () => {
    await expect(
      cruize.deposit(parseEther("1"), Constants.NULL_ADDRESS, {
        value: ethers.utils.parseEther("1"),
      })
    ).to.be.revertedWith("ZeroAddress");
  });

  it("Revert, if reserve address is not exist", async () => {
    await expect(
      cruize.deposit(
        ethers.utils.parseEther("1"),
        Constants.USER_WALLET_ADDRESS,
        { value: ethers.utils.parseEther("0") }
      )
    ).to.be.revertedWith("AssetNotAllowed");
  });

  it("Successfully Deposit ETH", async () => {
    await expect(
      cruize.connect(signer).deposit(parseEther("1"), Constants.ETH_ADDRESS, {
        value: parseEther("1"),
      })
    )
      .to.emit(cruize, "DepositEvent")
      .withArgs(Constants.ETH_ADDRESS, signer.address, parseEther("1"));

    await expect(
      cruize.connect(user0).deposit(parseEther("1"), Constants.ETH_ADDRESS, {
        value: parseEther("1"),
      })
    )
      .to.emit(cruize, "DepositEvent")
      .withArgs(Constants.ETH_ADDRESS, user0.address, parseEther("1"));
  });

  it.only("Successfully Deposit WETH by signer", async () => {
    await expect(
      cruize
        .connect(signer)
        .deposit(parseEther("2"), Constants.WETH_CONTRACT_ADDRESS, {
          value: parseEther("0"),
        })
    )
      .to.emit(cruize, "DepositEvent")
      .withArgs(
        Constants.WETH_CONTRACT_ADDRESS,
        signer.address,
        parseEther("2")
      );
  });

  it("Successfully Deposit wBTC by signer", async () => {
    await expect(
      cruize
        .connect(signer)
        .deposit(parseUnits("1", BigNumber.from(8)), Constants.WBTC, {
          value: parseEther("0"),
        })
    )
      .to.emit(cruize, "DepositEvent")
      .withArgs(
        Constants.WBTC,
        signer.address,
        parseUnits("1", BigNumber.from(8))
      );
  });

  it("Successfully Deposit WETH by user", async () => {
    await expect(
      cruize
        .connect(user0)
        .deposit(parseEther("2"), Constants.WETH_CONTRACT_ADDRESS, {
          value: parseEther("0"),
        })
    )
      .to.emit(cruize, "DepositEvent")
      .withArgs(
        Constants.WETH_CONTRACT_ADDRESS,
        user0.address,
        parseEther("2")
      );
  });

  it("change aave btc oracle", async () => {
    await aaveOracle.setAssetSources(
      ["0xf4423F4152966eBb106261740da907662A3569C5"],
      ["0x779877A7B0D9E8603169DdbD7836e478b4624789"]
    );
  });

  it("Successfully Deposit wBTC by user", async () => {
    await expect(
      cruize
        .connect(user0)
        .deposit(parseUnits("2", BigNumber.from(8)), Constants.WBTC, {
          value: parseEther("0"),
        })
    )
      .to.emit(cruize, "DepositEvent")
      .withArgs(
        Constants.WBTC,
        user0.address,
        parseUnits("2", BigNumber.from(8))
      );

    await increaseTime(2 * 86400);
  });

  /** @notice its for mainnet testing*/
  it("Repay USDC", async function () {
    const lending = await ethers.getContractAt(
      "IPoolV2",
      Constants.POOL,
      signer
    );
    console.log(await lending.callStatic.getUserAccountData(cruize.address));
    await cruize.connect(signer).repay(parseUnits("1400", BigNumber.from(6)));
    console.log(await lending.callStatic.getUserAccountData(cruize.address));
  });

  it("Simulate Fee deductions", async () => {
    await increaseTime(86400 * 10);
    await cruize
      .connect(signer)
      .payFee(Constants.ETH_ADDRESS, parseEther("0.001"));

    await cruize
      .connect(signer)
      .payFee(Constants.WETH_CONTRACT_ADDRESS, parseEther("0.001"));

    await cruize.connect(signer).payFee(Constants.WBTC, parseEther("0.01"));
  });

  it("Cruize Balance Before ETH Withdraw", async () => {
    console.table({
      ETH: await ethers.provider.getBalance(cruize.address),
      wETH: await wethToken.callStatic.balanceOf(cruize.address),
      wBTC: await wbtcToken.callStatic.balanceOf(cruize.address),
    });
  });

  it("Withdraw ETH, when price above the price floor", async () => {
    await crETH.connect(user0).approve(cruize.address, constants.MaxUint256);
    await crETH.connect(signer).approve(cruize.address, constants.MaxUint256);
    await expect(
      cruize
        .connect(user0)
        .withdraw(ethers.utils.parseEther("1"), Constants.ETH_ADDRESS)
    ).to.emit(cruize, "WithdrawEvent");

    await expect(
      cruize
        .connect(user0)
        .withdraw(ethers.utils.parseEther("1"), Constants.ETH_ADDRESS)
    ).revertedWith("ERC20: burn amount exceeds balance");

    expect(await ethers.provider.getBalance(cruize.address)).to.be.equal(
      parseEther("0.1")
    );

    await expect(
      cruize
        .connect(signer)
        .withdraw(ethers.utils.parseEther("1"), Constants.ETH_ADDRESS)
    ).to.emit(cruize, "WithdrawEvent");

    await expect(
      cruize
        .connect(signer)
        .withdraw(ethers.utils.parseEther("1"), Constants.ETH_ADDRESS)
    ).revertedWith("ERC20: burn amount exceeds balance");
  });

  it("Cruize Balance Before wBTC Withdraw", async () => {
    console.table({
      ETH: await ethers.provider.getBalance(cruize.address),
      wETH: await wethToken.callStatic.balanceOf(cruize.address),
      wBTC: await wbtcToken.callStatic.balanceOf(cruize.address),
    });
  });

  it("Cruize Balance Before wETH Withdraw", async () => {
    console.table({
      ETH: await ethers.provider.getBalance(cruize.address),
      wETH: await wethToken.callStatic.balanceOf(cruize.address),
      wBTC: await wbtcToken.callStatic.balanceOf(cruize.address),
    });
  });

  it("Withdraw wETH from signer, when price above the price floor", async () => {
    await crWETH.connect(signer).approve(cruize.address, constants.MaxUint256);
    await crWETH.connect(signer).transfer(user1.address,parseEther("0.5"));

    console.log(
      "BalanceOf Before Withdrawal: ",
      await crWETH.callStatic.balanceOf(signer.address)
    );
    
    console.log(
      "BalanceOf Before Withdrawal: ",
      await crWETH.callStatic.balanceOf(user0.address)
    );


    await expect(
      cruize
        .connect(signer)
        .withdraw(
          constants.MaxUint256,
          // await crWETH.callStatic.balanceOf(signer.address),
          Constants.WETH_CONTRACT_ADDRESS
        )
    ).to.emit(cruize, "WithdrawEvent");

    await increaseTime(3 * 86400);

    console.log(
      "BalanceOf After Withdrawal: ",
      await crWETH.callStatic.balanceOf(signer.address)
    );

  });

  it("Withdraw wBTC signer, when price above the price floor", async () => {
    await crWBTC.connect(signer).approve(cruize.address, constants.MaxUint256);

    await expect(
      cruize
        .connect(signer)
        .withdraw(
          await crWBTC.callStatic.balanceOf(signer.address),
          Constants.WBTC
        )
    ).to.emit(cruize, "WithdrawEvent");
    console.log(
      "BalanceOf: ",
      await crWBTC.callStatic.balanceOf(signer.address)
    );
  });

  it("Withdraw wETH from user, when price above the price floor", async () => {
    await crWETH.connect(user0).approve(cruize.address, constants.MaxUint256);
    // console.log(await cruize.callStatic.balanceOfAToken(user0.address,Constants.WETH_CONTRACT_ADDRESS));

    console.log(
      "BalanceOf Before Withdrawal: ",
      await crWETH.callStatic.balanceOf(user0.address)
    );


    await expect(
      cruize
        .connect(user0)
        .withdraw(
          constants.MaxUint256,
          // await crWETH.callStatic.balanceOf(user0.address),
          Constants.WETH_CONTRACT_ADDRESS
        )
    ).to.emit(cruize, "WithdrawEvent");
    // console.log(await cruize.callStatic.balanceOfAToken(user0.address,Constants.WETH_CONTRACT_ADDRESS));
  });

  it("Withdraw wBTC user0, when price above the price floor", async () => {
    await crWBTC.connect(user0).approve(cruize.address, constants.MaxUint256);

    await expect(
      cruize
        .connect(user0)
        .withdraw(
          await crWBTC.callStatic.balanceOf(user0.address),
          Constants.WBTC
        )
    ).to.emit(cruize, "WithdrawEvent");
  });

  it("Withdraw wETH from user1, when price above the price floor", async () => {
    await crWETH.connect(user1).approve(cruize.address, constants.MaxUint256);
    await increaseTime(3 * 86400);
    await expect(
      cruize
        .connect(user1)
        .withdraw(
          constants.MaxUint256,
          // await crWETH.callStatic.balanceOf(user0.address),
          Constants.WETH_CONTRACT_ADDRESS
        )
    ).to.emit(cruize, "WithdrawEvent");

    console.log(
      "BalanceOf: ",
      await crWETH.callStatic.balanceOf(signer.address)
    );
    console.log(
      "BalanceOf: ",
      await crWETH.callStatic.balanceOf(user0.address)
    );
    console.log(
      "BalanceOf: ",
      await crWETH.callStatic.balanceOf(user1.address)
    );
    
  });

  it("Revert, If user doesn't have enough crTokens", async () => {
    await expect(
      cruize
        .connect(signer)
        .withdraw(
          ethers.utils.parseEther("50"),
          Constants.WETH_CONTRACT_ADDRESS
        )
    ).to.be.revertedWith("ERC20: burn amount exceeds balance");
  });

  it("Revert, If user withdraw zero amount", async () => {
    await expect(
      cruize
        .connect(weth_holder)
        .withdraw(ethers.utils.parseEther("0"), Constants.WETH_CONTRACT_ADDRESS)
    ).to.be.revertedWith("ZeroAmount");
  });

  it("Revert, If token address is zero address", async () => {
    await expect(
      cruize
        .connect(weth_holder)
        .withdraw(ethers.utils.parseEther("1"), Constants.NULL_ADDRESS)
    ).to.be.revertedWith("ZeroAddress");
  });

  it("Cruize Balance should be zero", async () => {
    console.table({
      ETH: await ethers.provider.getBalance(cruize.address),
      wETH: await wethToken.callStatic.balanceOf(cruize.address),
      wBTC: await wbtcToken.callStatic.balanceOf(cruize.address),
    });
  });
});

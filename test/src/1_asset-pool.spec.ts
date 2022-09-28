import { expect } from "chai";
import * as dotenv from "dotenv";
import { BigNumber, constants, Contract } from "ethers";
import hre, { ethers } from "hardhat";
import { formatUnits, parseEther, parseUnits } from "ethers/lib/utils";
import { Impersonate, increaseTime, setBalanceZero } from "../utils/utilities";
import { Constants } from "../utils/constants";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

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
  let CRWETH: Contract;
  let crWETH: Contract;
  let crWBTC: Contract;
  let wbtcToken: Contract;
  let wethToken: Contract;
  let usdcToken: Contract;
  let linkToken: Contract;

  before(async () => {
    [signer, user0, user1, user2] = await ethers.getSigners();
    // signer = await Impersonate("0x71323401a728925edBAB9a29412868CA20bF6977");
    impersonateAccount = await Impersonate(Constants.USDC_AND_ETH_HOLDER);
    weth_holder = await Impersonate(Constants.WETH_HOLDER);
    btc_holder = await Impersonate(Constants.BTC_HOLDER);
    link_holder = await Impersonate(Constants.LINK_HOLDER)

    const Master = await ethers.getContractFactory(
      "CRTokenUpgradeable",
      signer
    );
    ERC20 = await Master.deploy();

    const AssetPool = await ethers.getContractFactory("Cruize", signer);
    cruize = await AssetPool.deploy();

    await cruize.initialize(signer.address, ERC20.address);

    wethToken = await ethers.getContractAt(
      "ERC20",
      Constants.WETH_CONTRACT_ADDRESS,
      impersonateAccount
    );

    wbtcToken = await ethers.getContractAt("ERC20", Constants.WBTC, btc_holder);

    usdcToken = await ethers.getContractAt(
      "ERC20",
      Constants.USDSC_CONTRACT_ADDRESS,
      impersonateAccount
    );

    linkToken = await ethers.getContractAt("ERC20","0x326C977E6efc84E512bB9C30f76E30c160eD06FB",link_holder)

    await loadContractAndApprove(
      "ERC20",
      Constants.USDSC_CONTRACT_ADDRESS,
      "2000000",
      cruize.address,
      signer
    );

    hre.tracer.nameTags[Constants.WBTC] = "WBTC";
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
    await usdcToken.connect(signer).transfer(cruize.address, "10000000000");

    await wethToken.connect(weth_holder).transfer(signer.address, parseEther("10"));

    await wethToken.connect(weth_holder).transfer(user0.address, parseEther("10"));

    await wbtcToken.connect(btc_holder).transfer(signer.address, "50000000000");

    await wbtcToken.connect(btc_holder).transfer(user0.address, "50000000000");
  });

  it.only("Throw, if re-intialize the asset pool contract", async () => {
    expect(cruize.initialize(signer.address, ERC20.address)).to.be.revertedWith(
      "Initializable: contract is already initialized"
    );
  });

  it.only("Throw, if asset or oracle addresses are zero addresses", async () => {
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

  it.only("Revert, if token name is an empty string", async () => {
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

  it.only("Revert, if token symbol is an empty string", async () => {
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

  it.only("Create CRETH", async () => {
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

  it.only("Revert, if amount is zero", async () => {
    await expect(
      cruize.deposit("0", Constants.WETH_CONTRACT_ADDRESS, {
        value: ethers.utils.parseEther("0"),
      })
    ).to.be.revertedWith("ZeroAmount");
  });

  it.only("Revert, if reserve address is zero address", async () => {
    await expect(
      cruize.deposit(parseEther("1"), Constants.NULL_ADDRESS, {
        value: ethers.utils.parseEther("1"),
      })
    ).to.be.revertedWith("ZeroAddress");
  });

  it.only("Revert, if reserve address is not exist", async () => {
    await expect(
      cruize.deposit(
        ethers.utils.parseEther("1"),
        Constants.USER_WALLET_ADDRESS,
        { value: ethers.utils.parseEther("0") }
      )
    ).to.be.revertedWith("AssetNotAllowed");
  });

  it.only("Successfully Deposit ETH", async () => {
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

  it.only("Successfully Deposit WETH", async () => {
    await expect(
      cruize
        .connect(signer)
        .deposit(parseEther("1"), Constants.WETH_CONTRACT_ADDRESS, {
          value: parseEther("0"),
        })
    )
      .to.emit(cruize, "DepositEvent")
      .withArgs(
        Constants.WETH_CONTRACT_ADDRESS,
        signer.address,
        parseEther("1")
      );

      await expect(
        cruize
          .connect(user0)
          .deposit(parseEther("1"), Constants.WETH_CONTRACT_ADDRESS, {
            value: parseEther("0"),
          })
      )
        .to.emit(cruize, "DepositEvent")
        .withArgs(
          Constants.WETH_CONTRACT_ADDRESS,
          user0.address,
          parseEther("1")
        );
  });

  it.only("Successfully Deposit wBTC", async () => {
    await expect(
      cruize
        .connect(signer)
        .deposit(parseUnits("0.1", BigNumber.from(8)), Constants.WBTC, {
          value: parseEther("0"),
        })
    )
      .to.emit(cruize, "DepositEvent")
      .withArgs(
        Constants.WBTC,
        signer.address,
        parseUnits("0.1", BigNumber.from(8))
      );

    await expect(
      cruize
        .connect(user0)
        .deposit(parseUnits("1", BigNumber.from(8)), Constants.WBTC, {
          value: parseEther("0"),
        })
    )
      .to.emit(cruize, "DepositEvent")
      .withArgs(
        Constants.WBTC,
        user0.address,
        parseUnits("1", BigNumber.from(8))
      );
  });

  /** @notic its for mainnet testing*/
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

  it.only("Cruize Balance Before ETH Withdraw", async () => {
    console.table({
      ETH: await ethers.provider.getBalance(cruize.address),
      wETH: await wethToken.callStatic.balanceOf(cruize.address),
      wBTC: await wbtcToken.callStatic.balanceOf(cruize.address),
    });
  });

  it.only("Withdraw ETH, when price above the price floor", async () => {
  await crETH.connect(user0).approve(cruize.address, constants.MaxUint256);
  await crETH.connect(signer).approve(cruize.address, constants.MaxUint256);

    await expect(
      cruize
        .connect(user0)
        .withdrawTest(
          ethers.utils.parseEther("1"),
          Constants.ETH_ADDRESS,
        )
    ).to.emit(cruize, "WithdrawEvent");

    await expect(
      cruize
        .connect(user0)
        .withdrawTest(
          ethers.utils.parseEther("1"),
          Constants.ETH_ADDRESS,
        )
    ).revertedWith("ERC20: burn amount exceeds balance");

    expect(await ethers.provider.getBalance(cruize.address)).to.be.equal(parseEther("0.1"))

    await expect(
      cruize
        .connect(signer)
        .withdrawTest(
          ethers.utils.parseEther("1"),
          Constants.ETH_ADDRESS,
        )
    ).to.emit(cruize, "WithdrawEvent");

    await expect(
      cruize
        .connect(signer)
        .withdrawTest(
          ethers.utils.parseEther("1"),
          Constants.ETH_ADDRESS,
        )
    ).revertedWith("ERC20: burn amount exceeds balance");

  });

  it.only("Cruize Balance Before wBTC Withdraw", async () => {
    console.table({
      ETH: await ethers.provider.getBalance(cruize.address),
      wETH: await wethToken.callStatic.balanceOf(cruize.address),
      wBTC: await wbtcToken.callStatic.balanceOf(cruize.address),
    });
  });

  it.only("Withdraw wBTC, when price above the price floor", async () => {

    await crWBTC.connect(user0).approve(cruize.address, constants.MaxUint256);
    await crWBTC.connect(signer).approve(cruize.address, constants.MaxUint256);

    await expect(
      cruize
        .connect(user0)
        .withdrawTest(
          parseUnits("1", BigNumber.from(8)),
          Constants.WBTC,
        )
    )
      .to.emit(cruize, "WithdrawEvent")

    expect(await wbtcToken.callStatic.balanceOf(cruize.address)).to.be.equal(parseUnits("0.01", BigNumber.from(8)))

      await expect(
        cruize
          .connect(signer)
          .withdrawTest(
            parseUnits("0.1", BigNumber.from(8)),
            Constants.WBTC,
          )
      )
        .to.emit(cruize, "WithdrawEvent")
  });

  it.only("Cruize Balance Before wETH Withdraw", async () => {
    console.table({
      ETH: await ethers.provider.getBalance(cruize.address),
      wETH: await wethToken.callStatic.balanceOf(cruize.address),
      wBTC: await wbtcToken.callStatic.balanceOf(cruize.address),
    });
  });

  it.only("Withdraw wETH, when price above the price floor", async () => {

    await crWETH
      .connect(user0)
      .approve(cruize.address, constants.MaxUint256);
      await crWETH
      .connect(signer)
      .approve(cruize.address, constants.MaxUint256);

    await expect(
      cruize
      .connect(user0)
      .withdrawTest(
        ethers.utils.parseEther("1"),
        Constants.WETH_CONTRACT_ADDRESS,
      ))
      .to.emit(cruize, "WithdrawEvent");

      await expect(
        cruize
        .connect(signer)
        .withdrawTest(
          ethers.utils.parseEther("1"),
          Constants.WETH_CONTRACT_ADDRESS,
        ))
        .to.emit(cruize, "WithdrawEvent");

  });

  it.only("Revert, If user doesn't have enough crTokens", async () => {
    await expect(
      cruize
        .connect(signer)
        .withdrawTest(
          ethers.utils.parseEther("50"),
          Constants.WETH_CONTRACT_ADDRESS,

        )
    ).to.be.revertedWith("ERC20: burn amount exceeds balance");
  });

  it.only("Revert, If user withdraw zero amount", async () => {
    await expect(
      cruize
        .connect(weth_holder)
        .withdrawTest(
          ethers.utils.parseEther("0"),
          Constants.WETH_CONTRACT_ADDRESS,
        )
    ).to.be.revertedWith("ZeroAmount");
  });

  it.only("Revert, If token address is zero address", async () => {
    await expect(
      cruize
        .connect(weth_holder)
        .withdrawTest(
          ethers.utils.parseEther("1"),
          Constants.NULL_ADDRESS,
        )
    ).to.be.revertedWith("ZeroAddress");
  });

  it.only("Cruize Balance should be zero", async () => {
    console.table({
      ETH: await ethers.provider.getBalance(cruize.address),
      wETH: await wethToken.callStatic.balanceOf(cruize.address),
      wBTC: await wbtcToken.callStatic.balanceOf(cruize.address),
    });
  });
  
});

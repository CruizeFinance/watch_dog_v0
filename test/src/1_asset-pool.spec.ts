import { expect } from "chai";
import * as dotenv from "dotenv";
import { Contract } from "ethers";
import hre, { ethers } from "hardhat";
import { parseEther } from "ethers/lib/utils";
import { Impersonate, increaseTime } from "../utils/utilities";
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
  let signer: SignerWithAddress;
  let cruize_wallet: SignerWithAddress;
  let impersonateAccount: SignerWithAddress;
  let weth_holder: SignerWithAddress;
  let assetPoolContract: Contract;
  let ERC20: Contract;
  let crETH: Contract;
  let CRWETH: Contract;
  let wethToken: Contract;
  let crWETH: Contract;
  let usdcToken: Contract;

 

  before(async () => {
    [signer, cruize_wallet] = await ethers.getSigners();
    impersonateAccount = await Impersonate(Constants.USDC_AND_ETH_HOLDER);
    weth_holder = await Impersonate(Constants.WETH_HOLDER);

    const Master = await ethers.getContractFactory("CRTokenUpgradeable",signer)
    ERC20 = await Master.deploy()

    const AssetPool = await ethers.getContractFactory("Cruize",signer)
    assetPoolContract = await AssetPool.deploy()

    await assetPoolContract.initialize(cruize_wallet.address, ERC20.address);

    wethToken = await ethers.getContractAt(
      "ERC20",
      Constants.WETH_CONTRACT_ADDRESS,
      impersonateAccount
    );

    usdcToken = await ethers.getContractAt(
      "ERC20",
      Constants.USDSC_CONTRACT_ADDRESS,
      impersonateAccount
    );

    await loadContractAndApprove(
      "ERC20",
      Constants.USDSC_CONTRACT_ADDRESS,
      "2000000",
      assetPoolContract.address,
      signer
    );

    await usdcToken.transfer(assetPoolContract.address, "1000000000");

    hre.tracer.nameTags[ERC20.address] = "CRTOKEN";
    hre.tracer.nameTags[Constants.USDSC_CONTRACT_ADDRESS] = "USDC";
    hre.tracer.nameTags[Constants.WETH_CONTRACT_ADDRESS] = "WETH";
    hre.tracer.nameTags[signer.address] = "ADMIN";
    hre.tracer.nameTags[cruize_wallet.address] = "CRUIZE WALLET";
    hre.tracer.nameTags[assetPoolContract.address] = "ASSET POOL CONTRACT";
    hre.tracer.nameTags[await impersonateAccount.getAddress()] = "USDC-HOLDER";
    hre.tracer.nameTags["0x030bA81f1c18d280636F32af80b9AAd02Cf0854e"] = "aWETH";
    hre.tracer.nameTags["0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c"] =
      "AAVE-COLLECTOR";
    hre.tracer.nameTags[Constants.POOL] = "AAVE-POOL";
  });

  it.only("Throw, if re-intialize the asset pool contract", async () => {
    expect(assetPoolContract.initialize(ERC20.address)).to.be.revertedWith(
      "Initializable: contract is already initialized"
    );
  });

  it.only("Throw, if asset or oracle addresses are zero addresses", async () => {
    await expect(
      assetPoolContract.createToken(
        "Cruize ETH",
        "CRETH",
        Constants.WETH_CONTRACT_ADDRESS,
        Constants.NULL_ADDRESS,
        Constants.ERC20_DECIMAL_VALUE
      )
    ).to.be.revertedWith("ZeroAddress");

    await expect(
      assetPoolContract.createToken(
        "Cruize ETH",
        "CRETH",
        Constants.NULL_ADDRESS,
        "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
        Constants.ERC20_DECIMAL_VALUE
      )
    ).to.be.revertedWith("ZeroAddress");
  });

  it.only("Revert, if token name is an empty string", async () => {
    await expect(
      assetPoolContract.createToken(
        "",
        "SYM",
        Constants.WETH_CONTRACT_ADDRESS,
        Constants.ETH_USD_ORACLE,
        Constants.ERC20_DECIMAL_VALUE
      )
    ).to.be.revertedWith("EmptyName");
  });

  it.only("Revert, if token symbol is an empty string", async () => {
    await expect(
      assetPoolContract.createToken(
        "CR Token",
        "",
        Constants.WETH_CONTRACT_ADDRESS,
        Constants.ETH_USD_ORACLE,
        Constants.ERC20_DECIMAL_VALUE
      )
    ).to.be.revertedWith("EmptySymbol");
  });

  it.only("Create CRETH", async () => {
    await expect(
      assetPoolContract.createToken(
        "Cruize ETH",
        "CRETH",
        Constants.ETH_ADDRESS,
        Constants.ETH_USD_ORACLE, // ETH-USD oracle address
        Constants.ERC20_DECIMAL_VALUE
      )
    ).to.emit(assetPoolContract, "CreateToken");

    //checking for the owner of the token
    const CRETHtoken = await assetPoolContract.lpTokens(Constants.ETH_ADDRESS);
    hre.tracer.nameTags[CRETHtoken] = "CRETH-TOKEN";

    crETH = await ethers.getContractAt(
      "CRTokenUpgradeable",
      CRETHtoken,
      signer
    );
    const CRETHTokenOwner = await crETH.owner();
    expect(CRETHTokenOwner).to.be.equal(assetPoolContract.address);
    await expect(
      assetPoolContract.createToken(
        "Cruize ETH",
        "CRETH",
        Constants.ETH_ADDRESS,
        Constants.ETH_USD_ORACLE, // ETH-USD oracle address
        Constants.ERC20_DECIMAL_VALUE
      )
    ).to.be.revertedWith("AssetAlreadyExists");
  });

  it.only("Create CRWETH", async () => {
    await expect(
      assetPoolContract.createToken(
        "Cruize WETH",
        "CRWETH",
        Constants.WETH_CONTRACT_ADDRESS,
        Constants.ETH_USD_ORACLE, // ETH-USD oracle address
        Constants.ERC20_DECIMAL_VALUE
      )
    ).to.emit(assetPoolContract, "CreateToken");

    //checking for the owner of the token
    const CRWETHtoken = await assetPoolContract.lpTokens(Constants.WETH_CONTRACT_ADDRESS);
    hre.tracer.nameTags[CRWETHtoken] = "CRETH-TOKEN";

    crWETH = await ethers.getContractAt("ERC20", CRWETHtoken, weth_holder);

    CRWETH = await ethers.getContractAt(
      "CRTokenUpgradeable",
      CRWETHtoken,
      signer
    );
    const CRWETHTokenOwner = await CRWETH.owner();
    expect(CRWETHTokenOwner).to.be.equal(assetPoolContract.address);
    await expect(
      assetPoolContract.createToken(
        "Cruize WETH",
        "CRWETH",
        Constants.WETH_CONTRACT_ADDRESS,
        Constants.ETH_USD_ORACLE, // ETH-USD oracle address
        Constants.ERC20_DECIMAL_VALUE
      )
    ).to.be.revertedWith("AssetAlreadyExists");
  });

  it.only("Revert, if amount is zero", async () => {
    await expect(
      assetPoolContract.deposit("0", Constants.WETH_CONTRACT_ADDRESS, {
        value: ethers.utils.parseEther("0"),
      })
    ).to.be.revertedWith("ZeroAmount");
  });

  it.only("Revert, if reserve address is zero address", async () => {
    await expect(
      assetPoolContract.deposit(parseEther("1"), Constants.NULL_ADDRESS, {
        value: ethers.utils.parseEther("1"),
      })
    ).to.be.revertedWith("ZeroAddress");
  });

  it.only("Revert, if reserve address is not exist", async () => {
    await expect(
      assetPoolContract.deposit(
        ethers.utils.parseEther("1"),
        Constants.USER_WALLET_ADDRESS,
        { value: ethers.utils.parseEther("0") }
      )
    ).to.be.revertedWith("AssetNotAllowed");
  });

  it.only("Successfully Deposit WETH", async () => {
    await wethToken
      .connect(weth_holder)
      .approve(assetPoolContract.address, parseEther("1000"));
    await expect(
      assetPoolContract
        .connect(weth_holder)
        .deposit(parseEther("1"), Constants.WETH_CONTRACT_ADDRESS, {
          value: parseEther("0"),
        })
    )
      .to.emit(assetPoolContract, "DepositEvent")
      .withArgs(await weth_holder.getAddress(), parseEther("1"));
  });

  it.only("Successfully Deposit ETH", async () => {
    expect(
      await assetPoolContract
        .connect(impersonateAccount)
        .deposit(parseEther("1"), Constants.ETH_ADDRESS, {
          value: parseEther("1"),
        })
    )
      .to.emit(assetPoolContract, "DepositEvent")
      .withArgs(impersonateAccount.address, parseEther("1"));
  });

  it.only("Repay USDC", async function () {
    await assetPoolContract
      .connect(weth_holder)
      .repay(ethers.constants.MaxUint256);
  });

  it.only("Revert, If user doesn't have enough crTokens", async () => {
    await expect(
      assetPoolContract.withdraw(
        ethers.utils.parseEther("20"),
        Constants.WETH_CONTRACT_ADDRESS
      )
    ).to.be.revertedWith("NotEnoughBalance");
  });

  it.only("Revert, If user withdraw zero amount", async () => {
    await expect(
      assetPoolContract.withdraw(
        ethers.utils.parseEther("0"),
        Constants.WETH_CONTRACT_ADDRESS,
        { value: parseEther("0") }
      )
    ).to.be.revertedWith("ZeroAmount");
  });

  it.only("Revert, If token address is zero address", async () => {
    await expect(
      assetPoolContract.withdraw(ethers.utils.parseEther("1"), Constants.NULL_ADDRESS, {
        value: parseEther("0"),
      })
    ).to.be.revertedWith("ZeroAddress");
  });

  it.only("Withdraw WETH and ETH", async () => {
    await increaseTime(86400 * 10);

    await crWETH
      .connect(weth_holder)
      .approve(assetPoolContract.address, parseEther("1000"));
    console.log(await crWETH.callStatic.balanceOf(Constants.WETH_HOLDER));

    await expect(
      assetPoolContract
        .connect(weth_holder)
        .withdraw(ethers.utils.parseEther("0.9"), Constants.WETH_CONTRACT_ADDRESS)
    )
      .to.emit(assetPoolContract, "WithdrawEvent")
      .withArgs(
        Constants.WETH_CONTRACT_ADDRESS,
        await weth_holder.getAddress(),
        parseEther("0.9")
      );

    await expect(
      assetPoolContract
        .connect(impersonateAccount)
        .withdraw(ethers.utils.parseEther("0.9"), Constants.ETH_ADDRESS)
    )
      .to.emit(assetPoolContract, "WithdrawEvent")
      .withArgs(
        Constants.ETH_ADDRESS,
        await impersonateAccount.getAddress(),
        parseEther("0.9")
      );

  });
});

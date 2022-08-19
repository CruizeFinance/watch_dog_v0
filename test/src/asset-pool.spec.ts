import { expect } from "chai";
import { Contract } from "ethers";
import hre, { ethers } from "hardhat";
import { parseEther } from "ethers/lib/utils";
import { Impersonate, increaseTime } from "../utils/utilities";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ERC20 } from "../../typechain";

//CONSTANT

//loading contracts ..
const loadAndDeployContract = async (
  factoryName: string,
  signer: SignerWithAddress
) => {
  const contractFactory = await ethers.getContractFactory(factoryName, signer);
  return await contractFactory.deploy();
};
//loading contracts and approving amount ..
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

describe.only("TESTING FOR ETH (NATIVE ETH)", function () {
  let signer: SignerWithAddress;
  let impersonateAccount: SignerWithAddress;
  let assetPoolContract: Contract;
  let ERC20: Contract;
  let aaveV2: Contract;
  let CRETH: Contract;
  let aavePool: Contract;

  const USER_WALLET_ADDRESS = "0xE0E24a32A7e50Ea1c7881c54bfC1934e9b50B520";
  const USDSC_CONTRACT_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  const USDC_AND_ETH_HOLDER = "0x72A53cDBBcc1b9efa39c834A540550e23463AAcB";
  const WETH_CONTRACT_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const ETH_USD_ORACLE = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";
  const NULL_ADDRESS = "0x0000000000000000000000000000000000000000";
  const ERC20_DECIMAL_VALUE = 18;

  before(async () => {
    [signer] = await ethers.getSigners();
    impersonateAccount = await Impersonate(USDC_AND_ETH_HOLDER);

    ERC20 = await loadAndDeployContract("CRTokenUpgradeable", signer);
    assetPoolContract = await loadAndDeployContract(
      "AssetPoolUpgradeable",
      signer
    );

    aaveV2 = await loadAndDeployContract("AaveV2Wrapper", signer);
    await aaveV2.transferOwnership(assetPoolContract.address);

    await assetPoolContract.initialize(ERC20.address, aaveV2.address);
    await loadContractAndApprove(
      "CRTokenUpgradeable",
      USDSC_CONTRACT_ADDRESS,
      "2000000",
      assetPoolContract.address,
      signer
    );

    aavePool = await ethers.getContractAt(
      "IPoolV2",
      "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9",
      signer
    );

    hre.tracer.nameTags[ERC20.address] = "CRTOKEN";
    hre.tracer.nameTags[USDSC_CONTRACT_ADDRESS] = "USDC";
    hre.tracer.nameTags[WETH_CONTRACT_ADDRESS] = "WETH";
    hre.tracer.nameTags[aaveV2.address] = "CRUIZE-WRAPPER";
    hre.tracer.nameTags[await signer.getAddress()] = "ADMIN";
    hre.tracer.nameTags[assetPoolContract.address] = "ASSET POOL CONTRACT";
    hre.tracer.nameTags[await impersonateAccount.getAddress()] = "USDC-HOLDER";
    hre.tracer.nameTags["0x030bA81f1c18d280636F32af80b9AAd02Cf0854e"] = "aWETH";
    hre.tracer.nameTags["0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c"] =
      "AAVE-COLLECTOR";
    hre.tracer.nameTags["0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9"] =
      "AAVE-POOL";
  });

  it.only("Throw, if re-intialize the asset pool contract", async () => {
    expect(
      assetPoolContract.initialize(ERC20.address, aaveV2.address)
    ).to.be.revertedWith("Initializable: contract is already initialized");
  });

  it.only("Throw, if asset or oracle addresses are zero addresses", async () => {
    await expect(
      assetPoolContract.createToken(
        "Cruize ETH",
        "CRETH",
        WETH_CONTRACT_ADDRESS,
        NULL_ADDRESS,
        ERC20_DECIMAL_VALUE
      )
    ).to.be.revertedWith("5");

    await expect(
      assetPoolContract.createToken(
        "Cruize ETH",
        "CRETH",
        NULL_ADDRESS,
        "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
        ERC20_DECIMAL_VALUE
      )
    ).to.be.revertedWith("5");
  });

  it.only("Revert, if token name is an empty string", async () => {
    await expect(
      assetPoolContract.createToken(
        "",
        "SYM",
        WETH_CONTRACT_ADDRESS,
        ETH_USD_ORACLE,
        ERC20_DECIMAL_VALUE
      )
    ).to.be.revertedWith("EMPTY_NAME");
  });

  it.only("Revert, if token symbol is an empty string", async () => {
    await expect(
      assetPoolContract.createToken(
        "CR Token",
        "",
        WETH_CONTRACT_ADDRESS,
        ETH_USD_ORACLE,
        ERC20_DECIMAL_VALUE
      )
    ).to.be.revertedWith("EMPTY_SYMBOL");
  });

  it.only("Create CRETH", async () => {
    await expect(
      assetPoolContract.createToken(
        "Cruize ETH",
        "CRETH",
        WETH_CONTRACT_ADDRESS,
        ETH_USD_ORACLE, // ETH-USD oracle address
        ERC20_DECIMAL_VALUE
      )
    ).to.emit(assetPoolContract, "CreateToken");

    //checking for the owner of the token
    const CRETHtoken = await assetPoolContract.lpTokens(WETH_CONTRACT_ADDRESS);
    hre.tracer.nameTags[CRETHtoken] = "CRETH-TOKEN";
    CRETH = await ethers.getContractAt(
      "CRTokenUpgradeable",
      CRETHtoken,
      signer
    );
    const CRETHTokenOwner = await CRETH.owner();
    expect(CRETHTokenOwner).to.be.equal(assetPoolContract.address);
    await expect(
      assetPoolContract.createToken(
        "Cruize ETH",
        "CRETH",
        WETH_CONTRACT_ADDRESS,
        ETH_USD_ORACLE, // ETH-USD oracle address
        ERC20_DECIMAL_VALUE
      )
    ).to.be.revertedWith("ALREADY_EXIST");
  });

  it.only("Revert, if amount is zero", async () => {
    await expect(
      assetPoolContract.depositAsset("0", WETH_CONTRACT_ADDRESS, {
        value: ethers.utils.parseEther("0"),
      })
    ).to.be.revertedWith("ZERO_AMOUNT");
  });

  it.only("Revert, if reserve address is zero address", async () => {
    await expect(
      assetPoolContract.depositAsset(parseEther("1"), NULL_ADDRESS, {
        value: ethers.utils.parseEther("1"),
      })
    ).to.be.revertedWith("ZERO_ADDRESS");
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

  it.only("Successfully Deposit ETH", async () => {
    await expect(
      assetPoolContract
        .connect(impersonateAccount)
        .depositAsset(ethers.utils.parseEther("10"), WETH_CONTRACT_ADDRESS, {
          value: ethers.utils.parseEther("10"),
        })
    )
      .to.emit(assetPoolContract, "DepositEvent")
      .withArgs(await impersonateAccount.getAddress(), parseEther("10"));
  });

  it.only("Revert, If user doesn't have enough crTokens", async () => {
    await expect(
      assetPoolContract.withdrawAsset(
        ethers.utils.parseEther("20"),
        WETH_CONTRACT_ADDRESS
      )
    ).to.be.revertedWith("NOT_ENOUGH_BALANCE");
  });

  it.only("Revert, If user withdraw zero amount", async () => {
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
    await increaseTime(86400 * 10);

    console.log(await aavePool.callStatic.getUserAccountData(aaveV2.address));

    await expect(
      assetPoolContract
        .connect(impersonateAccount)
        .withdrawAsset(ethers.utils.parseEther("10"), WETH_CONTRACT_ADDRESS)
    )
      .to.emit(assetPoolContract, "WithdrawEvent")
      .withArgs(
        WETH_CONTRACT_ADDRESS,
        await impersonateAccount.getAddress(),
        parseEther("10")
      );

    console.log(await aavePool.callStatic.getUserAccountData(aaveV2.address));
  });
});

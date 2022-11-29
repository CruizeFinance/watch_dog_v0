import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import { DeployFunction, Deployment } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import {Constants} from "../../test/utils/constants"
import { contractNames } from '../ts/deploy';

const deployContract: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
) {
  const { deployments, getNamedAccounts } = hre;
  // const { deployer } = await getNamedAccounts();
  const { deploy, get } = deployments;
  const {
    CruizeTest,
    CrMaster
    } = contractNames;

  let cruize: Deployment;
  let crMaster: Deployment;
  let oracle: Deployment;
  const signer:SignerWithAddress = await hre.ethers.getSigner("0x9A3310233aaFe8930d63145CC821FF286c7829e1");
  const deployer = signer.address
  console.log("Signers:",signer)
  console.log("deployer:",deployer)

  await deploy(CruizeTest, {
    from: deployer,
    args: [],
    log: true,
    deterministicDeployment: false,
  }
  )
  cruize = await get(CruizeTest);

  await deploy(CrMaster, {
    from: deployer,
    args: [],
    log: true,
    deterministicDeployment: false,
  }
  )
  crMaster = await get(CrMaster);

  await deploy("APIConsumer" , {
    from: deployer,
    args:[],
    log:true
  })

  oracle = await get("APIConsumer");

  const oracleInstance  = await ethers.getContractAt("APIConsumer",oracle.address,signer)
  await oracleInstance.requestBtcPriceFloor()
  await oracleInstance.requestEthPriceFloor()
  console.table({
    crMaster:crMaster.address,
    cruize: cruize.address,
    oracle : oracle.address
  })

  const cruizeInstance = await ethers.getContractAt(CruizeTest,cruize.address,signer)

  await cruizeInstance.connect(signer).initialize(
    signer.address,
    "0xFc8D78e8a99E8B6d5475c15875Fd0A82e58e0116"
  )
  
  await cruizeInstance.connect(signer).createToken(
    "Cruize ETH",
    "crETH",
    Constants.ETH_ADDRESS,
    Constants.ETH_USD_ORACLE, // ETH-USD oracle address
    Constants.ERC20_DECIMAL_VALUE,
    100
  )

  await cruizeInstance.connect(signer).createToken(
    "Cruize WETH",
    "crWETH",
    Constants.WETH_CONTRACT_ADDRESS,
    Constants.ETH_USD_ORACLE, // ETH-USD oracle address
    Constants.ERC20_DECIMAL_VALUE,
    100
  )

  await cruizeInstance.connect(signer).createToken(
    "Cruize WBTC",
    "crWBTC",
    Constants.WBTC,
    Constants.WBTC_USD_ORACLE, // BTC-USD oracle address
    8,
    3000
  )

  try {
    await hre.run('verify', {
      address: cruize.address,
      constructorArgsParams: [],
    })
  } catch (error) {
    console.log(`Smart contract at address ${cruize.address} is already verified`)
  }

  try {
    await hre.run('verify', {
      address: crMaster.address,
      constructorArgsParams: [],
    })
  } catch (error) {
    console.log(`Smart contract at address ${crMaster.address} is already verified`)
  }

  try {
    await hre.run('verify', {
      address: oracle.address,
      constructorArgsParams: [],
    })
  } catch (error) {
    console.log(`Smart contract at address ${oracle.address} is already verified`)
  }


}

export default deployContract

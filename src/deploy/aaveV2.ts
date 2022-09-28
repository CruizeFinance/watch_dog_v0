import { Contract } from '@ethersproject/contracts'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { parseEther } from 'ethers/lib/utils';
import { ethers } from 'hardhat';
import { DeployFunction, Deployment } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { Constants } from '../../test/utils/constants';

import { contractNames } from '../ts/deploy';

const deployContract: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
) {
  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();
  const { deploy, get } = deployments;
  const {
    Cruize,
    CrMaster
    } = contractNames;

  let cruize: Deployment;
  let crMaster: Deployment;
  let oracle: Deployment;
  const signers:SignerWithAddress[] = await hre.ethers.getSigners();

  console.log("Signers:",signers[1].address)

  await deploy(Cruize, {
    from: deployer,
    args: [],
    log: true,
    deterministicDeployment: false,
  }
  )
  cruize = await get(Cruize);

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

  const oracleInstance  = await ethers.getContractAt("APIConsumer","0x42CB4809E2F0926aEB994874aD176c67014Da902",signers[1])
  await oracleInstance.requestBtcPriceFloor()
  await oracleInstance.requestEthPriceFloor()
  console.table({
    crMaster:crMaster.address,
    cruize: cruize.address,
    oracle : oracle.address
  })

  const cruizeInstance = await ethers.getContractAt("Cruize",cruize.address,signers[1])

  await cruizeInstance.connect(signers[1]).initialize(
    signers[1].address,
    "0xFc8D78e8a99E8B6d5475c15875Fd0A82e58e0116"
  )
  
  await cruizeInstance.connect(signers[1]).createToken(
    "Cruize ETH",
    "crETH",
    Constants.ETH_ADDRESS,
    Constants.ETH_USD_ORACLE, // ETH-USD oracle address
    Constants.ERC20_DECIMAL_VALUE,
    100
  )

  await cruizeInstance.connect(signers[1]).createToken(
    "Cruize WETH",
    "crWETH",
    Constants.WETH_CONTRACT_ADDRESS,
    Constants.ETH_USD_ORACLE, // ETH-USD oracle address
    Constants.ERC20_DECIMAL_VALUE,
    100
  )

  await cruizeInstance.connect(signers[1]).createToken(
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
    console.log(error)
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

import { Contract } from '@ethersproject/contracts'
import { DeployFunction, Deployment } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

import { contractNames } from '../ts/deploy';

interface IDeployedContracts {
  [P: string]: Contract;
}

const deployContract: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
) {
  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();
  const { deploy, get } = deployments;
  const {
    AaveV2Wrapper,
    } = contractNames;

  let wrapper: Deployment;
  const signers = await hre.ethers.getSigners();

  await deploy(AaveV2Wrapper, {
    from: deployer,
    args: [
      
    ],
    log: true,
    deterministicDeployment: false,
  }
  )
  wrapper = await get(AaveV2Wrapper);

  

  console.log("testToken", wrapper.address)


  try {
    await hre.run('verify', {
      address: wrapper.address,
      constructorArgsParams: [],
    })
  } catch (error) {
    console.log(`Smart contract at address ${wrapper.address} is already verified`)
  }


}

export default deployContract

import { Contract } from '@ethersproject/contracts'
import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

import { contractNames } from '../ts/deploy';

interface IDeployedContracts {
  [P: string]: Contract;
}

const deployCruizeContract: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
) {
  const {
    AssetPool } = contractNames;

  let contracts: IDeployedContracts = {};
  const signers = await hre.ethers.getSigners();

  const testToken = await hre.ethers.getContractFactory(AssetPool, signers[0])
  contracts.TestToken = await testToken.deploy()

}

export default deployCruizeContract

import hre from "hardhat";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber, Signer, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

export const getTime = async (): Promise<number> => {
    return (await hre.ethers.provider.getBlock("latest")).timestamp
}

export async function increaseTime(duration: number): Promise<void> {
    ethers.provider.send("evm_increaseTime", [duration]);
    ethers.provider.send("evm_mine", []);
}

export const Impersonate = async(address:string):Promise<SignerWithAddress> =>{
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [address],
      });
    
      const account = await ethers.getSigner(address)
      return account;
}
import { Contract, Signer } from "ethers";
import { ethers } from "hardhat";
import "@nomiclabs/hardhat-ethers";

async function main() {
    const signers: Signer[] = await ethers.getSigners()
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.log(error);
        process.exit(1);
    })
import { expect } from "chai";
import { Contract, Signer } from "ethers";
import hre, { ethers } from "hardhat";

import { getTime } from "../utils/utilities";

describe("Cruize Protocol", function () {

  let signers: Signer[];

  let poolInstance: Contract;


  before(async () => {
    signers = await ethers.getSigners();

    hre.tracer.nameTags[await signers[0].getAddress()] = "ADMIN";
  

  });


  it("hi", async function () {
  })

});

const USDCPool  = artifacts.require("USDCPool");
module.exports = function (deployer) {
  deployer.deploy(USDCPool);
};

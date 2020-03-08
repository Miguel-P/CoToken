const CoToken = artifacts.require("CoToken");

module.exports = function(deployer) {
  deployer.deploy(CoToken);
};

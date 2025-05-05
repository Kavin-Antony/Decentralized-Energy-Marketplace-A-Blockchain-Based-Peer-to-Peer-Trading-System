const EnergyTrade = artifacts.require("EnergyTrade");

module.exports = function (deployer) {
  deployer.deploy(EnergyTrade);
};
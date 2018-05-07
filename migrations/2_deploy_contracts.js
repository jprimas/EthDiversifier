var DiversifyContract = artifacts.require("Diversify");
var TestCoinOne = artifacts.require("TestCoinOne");
var TestCoinTwo = artifacts.require("TestCoinTwo");

module.exports = function(deployer) {
	// deployer.deploy(TestCoinOne);
	// deployer.deploy(TestCoinTwo);
	deployer.deploy(DiversifyContract, "0xf17f52151EbEF6C7334FAD080c5704D77216b732");
};
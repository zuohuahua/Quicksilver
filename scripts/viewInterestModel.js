const Qstroller = artifacts.require("Qstroller");
const Unitroller = artifacts.require("Unitroller");
const InterestModel = artifacts.require("HecoJumpInterestModel");
const CToken = artifacts.require("CToken");

module.exports = async function(callback) {
    try {
        let unitrollerInstance = await Unitroller.deployed();
        let proxiedQstroller = await Qstroller.at(unitrollerInstance.address);
        let allSupportedMarkets = await proxiedQstroller.getAllMarkets();
        for (market of allSupportedMarkets) {
            let cTokenInstance = await CToken.at(market);
            let cTokenName = await cTokenInstance.name();
            let compSpeed = await proxiedQstroller.compSpeeds(market);
            if (compSpeed <= 0) continue;
            let interestRateModel = await cTokenInstance.interestRateModel();
            let interestRateModelInstance = await InterestModel.at(interestRateModel);
            let blocksPerYear = await interestRateModelInstance.blocksPerYear();
            let multiplierPerBlock = await interestRateModelInstance.multiplierPerBlock();
            let baseRatePerBlock = await interestRateModelInstance.baseRatePerBlock();
            let jumpMultiplierPerBlock = await interestRateModelInstance.jumpMultiplierPerBlock();
            console.log(`${cTokenName} ${market} interestModel: ${interestRateModel} blocksPerYear: ${blocksPerYear} multiplierPerBlock: ${multiplierPerBlock} baseRatePerBlock: ${baseRatePerBlock} jumpMultiplierPerBlock: ${jumpMultiplierPerBlock}`);
        }
        callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
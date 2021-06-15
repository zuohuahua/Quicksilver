const Qstroller = artifacts.require("Qstroller");
const Unitroller = artifacts.require("Unitroller");
const InterestModel = artifacts.require("HecoJumpInterestModel");
const CToken = artifacts.require("CToken");

module.exports = async function(callback) {
    try {
        let marketInterestModel = {};
        let unitrollerInstance = await Unitroller.deployed();
        let proxiedQstroller = await Qstroller.at(unitrollerInstance.address);
        let allSupportedMarkets = await proxiedQstroller.getAllMarkets();
        // let allSupportedMarkets = ["0x0d37214e9A4B6E1AE3bA664bac3A6f0cbDa06665","0x0b3f6F8B72011F9Af56bfF9cd785633cC3BbEf18"];
        for (market of allSupportedMarkets) {
            let cTokenInstance = await CToken.at(market);
            let cTokenName = await cTokenInstance.name();
            let compSpeed = await proxiedQstroller.compSpeeds(market);
            if (compSpeed <= 0) continue;
            let reserveFactorMantissa = await cTokenInstance.reserveFactorMantissa() / Math.pow(10, 18);
            let interestRateModel = await cTokenInstance.interestRateModel();
            let interestRateModelInstance = await InterestModel.at(interestRateModel);
            let blocksPerYear = await interestRateModelInstance.blocksPerYear();
            let multiplierPerBlock = await interestRateModelInstance.multiplierPerBlock();
            let baseRatePerBlock = await interestRateModelInstance.baseRatePerBlock();
            let jumpMultiplierPerBlock = await interestRateModelInstance.jumpMultiplierPerBlock();
            let kink = await interestRateModelInstance.kink();
            marketInterestModel[interestRateModel] = market;
            console.log(`${cTokenName} ${market} reserveFactorMantissa: ${reserveFactorMantissa.toFixed(2)} interestModel: ${interestRateModel} blocksPerYear: ${blocksPerYear} baseRatePerBlock: ${(baseRatePerBlock * blocksPerYear/Math.pow(10, 18)).toFixed(2)} multiplierPerBlock: ${(multiplierPerBlock * blocksPerYear/Math.pow(10, 18)).toFixed(2)} kink: ${kink/Math.pow(10, 18)} jumpMultiplierPerBlock: ${(jumpMultiplierPerBlock * blocksPerYear/Math.pow(10, 18)).toFixed(2)}`);
        }
        console.log("marketInterestModel: ", marketInterestModel)
        callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
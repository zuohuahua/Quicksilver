const Qstroller = artifacts.require("Qstroller");
const Unitroller = artifacts.require("Unitroller");
const CToken = artifacts.require("CToken");

module.exports = async function(callback) {
    try {
        let unitrollerInstance = await Unitroller.deployed();
        let proxiedQstroller = await Qstroller.at(unitrollerInstance.address);
        let allSupportedMarkets = await proxiedQstroller.getAllMarkets();
        let tokens = [];
        let compSpeeds = [];
        for (market of allSupportedMarkets) {
            let cTokenInstance = await CToken.at(market);
            let cTokenName = await cTokenInstance.name();
            let compSpeed = await proxiedQstroller.compSpeeds(market);
            if (compSpeed <= 0) continue;
            let marketState = await proxiedQstroller.markets(market);
            let collateralRatio = marketState['collateralFactorMantissa'].toString()/Math.pow(10, 16);
            console.log(`${cTokenName} ${market} collateralFactor: ${collateralRatio}%`);
        }
        callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
const Qstroller = artifacts.require("Qstroller");
const Unitroller = artifacts.require("Unitroller");
const CToken = artifacts.require("CToken");

module.exports = async function(callback) {
    try {
        let unitrollerInstance = await Unitroller.deployed();
        let proxiedQstroller = await Qstroller.at(unitrollerInstance.address);
        let allSupportedMarkets = await proxiedQstroller.getAllMarkets();
        for (market of allSupportedMarkets) {
            let cTokenInstance = await CToken.at(market);
            let cTokenName = await cTokenInstance.name();
            let totalReserves = await cTokenInstance.totalReserves();
            let reserveFactorMantissa = await cTokenInstance.reserveFactorMantissa();
            console.log(`${cTokenName} totalReserves: ${totalReserves}, reserveFactorMantissa: ${reserveFactorMantissa}`)
        }
        callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
const Qstroller = artifacts.require("Qstroller");
const CToken = artifacts.require("CToken");
const Unitroller = artifacts.require("Unitroller");
const reserveFactor = 0.10e18.toString();

module.exports = async function(callback) {
    try {
        let unitrollerInstance = await Unitroller.deployed();
        let proxiedQstroller = await Qstroller.at(unitrollerInstance.address);
        let allSupportedMarkets = await proxiedQstroller.getAllMarkets();
        for (market of allSupportedMarkets) {
            let cTokenInstance = await CToken.at(market);
            let cTokenName = await cTokenInstance.name();
            await cTokenInstance._setReserveFactor(reserveFactor);
            console.log(`reserveFactor is set to ${reserveFactor} for ${cTokenName} : ${cTokenInstance.address}`);
        }
        callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
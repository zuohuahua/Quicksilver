const Qstroller = artifacts.require("Qstroller");
const Unitroller = artifacts.require("Unitroller");

module.exports = async function(callback) {
    try {
        const previousQstrollerAddress = "0xC5361650B1E5E71F2514931A1D73849565A1C269";
       let previousControllerInstance = await Qstroller.at(previousQstrollerAddress);
       let unitrollerInstance = await Unitroller.deployed();
       let impl = await unitrollerInstance.comptrollerImplementation();
       console.log(`current implementation: ${impl}`, );
       await unitrollerInstance._setPendingImplementation(previousQstrollerAddress);
       await previousControllerInstance._become(unitrollerInstance.address);
       impl = await unitrollerInstance.comptrollerImplementation();
       console.log(`new implementation: ${impl}`);
        let proxiedQstroller = await Qstroller.at(unitrollerInstance.address);
        let allSupportedMarkets = await proxiedQstroller.getAllMarkets();
        console.log(allSupportedMarkets);
       callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
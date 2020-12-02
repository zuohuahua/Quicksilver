const Qstroller = artifacts.require("Qstroller");
const sELA = artifacts.require("CEther");
const Unitroller = artifacts.require("Unitroller");
const InterestModel = artifacts.require("WhitePaperInterestRateModel");

module.exports = async function(callback) {
    try {
        let qstrollerInstance = await Qstroller.at(Unitroller.address);
        let admin = await qstrollerInstance.admin();

        console.log(`Qstroller: ${Qstroller.address}`);
        let newSEla = await sELA.new(Unitroller.address, InterestModel.address, 0.02e18.toString(), "QuickSilver ELA", "sELA", 18, admin);
        console.log(`Newly created sELA: ${newSEla.address}`)
        await qstrollerInstance._supportMarket(newSEla.address);
        console.log("Done to support market sELA: ", newSEla.address);
        let elaCollateralFactor = 0.15e18.toString();
        await qstrollerInstance._setCollateralFactor(newSEla.address, elaCollateralFactor);
        let sElaMarket = await qstrollerInstance.markets(newSEla.address);
        console.log("Done to set collateral factor %s for sELA %s", sElaMarket.collateralFactorMantissa, newSEla.address);
        callback();
    } catch (e) {
        callback(e);
    }
}

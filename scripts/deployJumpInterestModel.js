const JumpInterestModel = artifacts.require("HecoJumpInterestModel");
const CToken = artifacts.require("CToken");
const Qstroller = artifacts.require("Qstroller");
const Unitroller = artifacts.require("Unitroller");

const baseRatePerYear = 0.03e18.toString()
const multiplierPerYear = 0.4e18.toString()
const jumpMultiplierPerYear = 5.2e18.toString()
const kink = 0.8e18.toString()
const reserveFactor = 0.15e18.toString();

module.exports = async function(callback) {
    try {
        let newInterestModel = await JumpInterestModel.new(baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink);
        let allSupportedMarkets = ["0x824151251B38056d54A15E56B73c54ba44811aF8"]
        for (market of allSupportedMarkets) {
            let interestModelAddr = newInterestModel.address;
            let cTokenInstance = await CToken.at(market);
            let cTokenName = await cTokenInstance.name();
            console.log(`cTokenName: ${cTokenName}`)
            let oldInterestModelAddr = await cTokenInstance.interestRateModel();
            //if (oldInterestModelAddr != "0x9f76E988eE3a0d5F13c9bd693F72CF8c203E3b9c") continue;
            await cTokenInstance._setInterestRateModel(interestModelAddr);
            await cTokenInstance._setReserveFactor(reserveFactor);
            let newInterestModelAddr = await cTokenInstance.interestRateModel();
            console.log(`oldInterestModel ${oldInterestModelAddr} is replaced with newInterestModel: ${newInterestModelAddr} for token ${cTokenName} : ${cTokenInstance.address}`);
        }
        callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
const JumpInterestModel = artifacts.require("HecoJumpInterestModel");
const CToken = artifacts.require("CToken");
const Qstroller = artifacts.require("Qstroller");
const Unitroller = artifacts.require("Unitroller");

const baseRatePerYear = "30000000000000000"
const multiplierPerYear = "300000000000000000"
const jumpMultiplierPerYear = "5000000000000000000"
const kink = "950000000000000000"
const reserveFactor = 0.2e18.toString();

module.exports = async function(callback) {
    try {
        let newInterestModel = await JumpInterestModel.new(baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink);
        let allSupportedMarkets = ["0xB16Df14C53C4bcfF220F4314ebCe70183dD804c0","0xAab0C9561D5703e84867670Ac78f6b5b4b40A7c1"]
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
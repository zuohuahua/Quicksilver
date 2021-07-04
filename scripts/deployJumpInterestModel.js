const JumpInterestModel = artifacts.require("HecoJumpInterestModel");
const CToken = artifacts.require("CToken");
const Qstroller = artifacts.require("Qstroller");
const Unitroller = artifacts.require("Unitroller");

const baseRatePerYear = 0.05e18.toString()
const multiplierPerYear = 0.57e18.toString()
const jumpMultiplierPerYear = 3e18.toString()
const kink = 0.8e18.toString()
const reserveFactor = 0.15e18.toString();

module.exports = async function(callback) {
    try {
        let newInterestModel = await JumpInterestModel.new(baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink);
        let allSupportedMarkets = ["0xfEA846A1284554036aC3191B5dFd786C0F4Db611","0x74F8D9B701bD4d8ee4ec812AF82C71EB67B9Ec75","0x9E6f8357bae44C01ae69df807208c3f5E435BbeD"]
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
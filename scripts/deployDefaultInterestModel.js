const Qstroller = artifacts.require("Qstroller");
const Unitroller = artifacts.require("Unitroller");
const DefaultInterestModel = artifacts.require("DefaultHecoInterestModel");
const CToken = artifacts.require("CToken");

module.exports = async function(callback) {
    try {
        //let newInterestModel = await DefaultInterestModel.new("20000000000000000", "350000000000000000");
        let allSupportedMarkets = ["0x4937A83Dc1Fa982e435aeB0dB33C90937d54E424"]
        for (market of allSupportedMarkets) {
            //let interestModelAddr = newInterestModel.address;
            let interestModelAddr = "0x19BF5a8172c93d1819d27695cd7e4801aE97d2e9"
            let cTokenInstance = await CToken.at(market);
            let cTokenName = await cTokenInstance.name();
            let oldInterestModelAddr = await cTokenInstance.interestRateModel();
            //if (oldInterestModelAddr != "0x9f76E988eE3a0d5F13c9bd693F72CF8c203E3b9c") continue;
            await cTokenInstance._setInterestRateModel(interestModelAddr);
            let newInterestModelAddr = await cTokenInstance.interestRateModel();
            console.log(`oldInterestModel ${oldInterestModelAddr} is replaced with newInterestModel: ${newInterestModelAddr} for token ${cTokenName} : ${cTokenInstance.address}`);
        }
        callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
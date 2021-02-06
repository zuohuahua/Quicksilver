const JumpInterestModel = artifacts.require("HecoJumpInterestModel");
const CToken = artifacts.require("CToken");
const Qstroller = artifacts.require("Qstroller");
const Unitroller = artifacts.require("Unitroller");

const baseRatePerYear = "20000000000000000"
const multiplierPerYear = "320000000000000000"
const jumpMultiplierPerYear = "5000000000000000000"
const kink = "950000000000000000"

module.exports = async function(callback) {
    try {
        let newInterestModel = await JumpInterestModel.new(baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink);
        let allSupportedMarkets = ["0x824151251B38056d54A15E56B73c54ba44811aF8","0x0AD0bee939E00C54f57f21FBec0fBa3cDA7DEF58","0x749E0198f12559E7606987F8e7bD3AA1DE6d236E","0x033F8C30bb17B47f6f1f46F3A42Cc9771CCbCAAE","0xF2a308d3Aea9bD16799A5984E20FDBfEf6c3F595","0xCca471B0d49c0d4835a5172Fd97ddDEA5C979100","0x09e3d97A7CFbB116B416Dae284f119c1eC3Bd5ea"]
        for (market of allSupportedMarkets) {
            let interestModelAddr = newInterestModel.address;
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
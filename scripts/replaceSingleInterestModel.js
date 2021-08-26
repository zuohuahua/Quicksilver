const InterestModel = artifacts.require("DefaultHecoInterestModel");
const CToken = artifacts.require("CToken");
const reserveFactor = 0.15e18.toString();

const argv = require('yargs').argv;

module.exports = async function(callback) {
    try {
        console.log(`argv> market=${argv.market}`);
        let newInterestModel = await InterestModel.new("50000000000000000", "500000000000000000");
        let interestModelAddr = newInterestModel.address;
        let cTokenInstance = await CToken.at(argv.market);
        let cTokenName = await cTokenInstance.name();
        let oldInterestModelAddr = await cTokenInstance.interestRateModel();
        await cTokenInstance._setInterestRateModel(interestModelAddr);
        await cTokenInstance._setReserveFactor(reserveFactor);
        let newInterestModelAddr = await cTokenInstance.interestRateModel();
        console.log(`oldInterestModel ${oldInterestModelAddr} is replaced with newInterestModel: ${newInterestModelAddr} for token ${cTokenName} : ${cTokenInstance.address}`);
        callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
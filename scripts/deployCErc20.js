const Qstroller = artifacts.require("Qstroller");
const erc20Delegate = artifacts.require("CErc20Delegate");
const erc20Delegator = artifacts.require("CErc20Delegator");
const Unitroller = artifacts.require("Unitroller");
const InterestModel = artifacts.require("WhitePaperInterestRateModel");
const initialExchangeRateMantissa = 0.02e18.toString();

const argv = require('yargs').argv;

let reserveFactor = 0.3e18.toString();
let underlyingTokenAddr = "0xd3f1be7f74d25f39184d2d0670966e2e837562e3";
let sTokenName = "QuickSilver ethHFIL";
let sTokenSymbol = "sEthHFIL";
let collateralFactor = 0.5e18.toString();

module.exports = async function(callback) {
    try {
        console.log(`argv> token=${argv.token}, sTokenName=${argv.sTokenName}, sTokenSymbol=${argv.sTokenSymbol}, collateralFactor=${argv.collateralFactor}`);
        underlyingTokenAddr = argv.token
        sTokenName = argv.sTokenName
        sTokenSymbol = argv.sTokenSymbol
        collateralFactor = argv.collateralFactor

        let qsControllerInstance = await Qstroller.at(Unitroller.address);
        let admin = await qsControllerInstance.admin();
        let newErc20Delegate = await erc20Delegate.new();
        let sTokenInstance = await erc20Delegator.new(underlyingTokenAddr, Unitroller.address, InterestModel.address, initialExchangeRateMantissa, sTokenName, sTokenSymbol, 18, admin, newErc20Delegate.address, "0x0");
        await sTokenInstance._setReserveFactor(reserveFactor);

        await qsControllerInstance._supportMarket(sTokenInstance.address);
        console.log(`Done to support market ${sTokenSymbol}: ${sTokenInstance.address}`);

        await qsControllerInstance._setCollateralFactor(sTokenInstance.address, collateralFactor);
        console.log("Done to set collateral factor %s for %s %s", collateralFactor, sTokenSymbol, sTokenInstance.address);
        callback();
    } catch (e) {
        callback(e);
    }
}

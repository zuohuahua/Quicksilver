const Qstroller = artifacts.require("Qstroller");
const erc20Delegate = artifacts.require("CErc20Delegate");
const erc20Delegator = artifacts.require("CErc20Delegator");
const Unitroller = artifacts.require("Unitroller");
const erc20Token = artifacts.require("EIP20Interface");

const argv = require('yargs').option('token', {string:true}).argv;

let underlyingTokenAddr = "";
module.exports = async function(callback) {
    try {
        console.log(`argv> token=${argv.token}, fToken=${argv.fToken}`);
        underlyingTokenAddr = argv.token
        let fTokenAddress = argv.fToken

        let erc20 = await erc20Token.at(underlyingTokenAddr);
        let decimals = await erc20.decimals();
        let symbol = await erc20.symbol();
        let fTokenName = "Filda " + symbol;
        let fTokenSymbol = "f" + symbol.charAt(0).toUpperCase() + symbol.slice(1)
        console.log(`TokenDecimals: ${decimals}`)
        console.log(`TokenSymbol: ${symbol}`);
        console.log(`fTokenName: ${fTokenName}`)
        console.log(`fTokenSymbol: ${fTokenSymbol}`)

        let qsControllerInstance = await Qstroller.at(Unitroller.address);
        let fTokenInstance = await erc20Delegator.at(fTokenAddress);
        let oldImpl = await fTokenInstance.implementation();
        let newErc20Delegate = await erc20Delegate.new();
        await fTokenInstance._setImplementation(newErc20Delegate.address, false, "0x0");
        let newImpl = await fTokenInstance.implementation();
        console.log("Done to upgrade implementation to ", newImpl, " from ", oldImpl);

        fTokenName = await fTokenInstance.name();
        console.log("fTokenName after upgrade: ", fTokenName);
        console.log("MintPaused: ", await qsControllerInstance.mintGuardianPaused(fTokenInstance.address))
        callback();
    } catch (e) {
        callback(e);
    }
}

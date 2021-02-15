const Qstroller = artifacts.require("Qstroller");
const CToken = artifacts.require("CToken");
const Unitroller = artifacts.require("Unitroller");
const reserveFactor = 0.25e18.toString();
module.exports = async function(callback) {
    try {
        let unitrollerInstance = await Unitroller.deployed();
        let proxiedQstroller = await Qstroller.at(unitrollerInstance.address);
        //let allSupportedMarkets = await proxiedQstroller.getAllMarkets();
        let allSupportedMarkets = ["0xB16Df14C53C4bcfF220F4314ebCe70183dD804c0","0xAab0C9561D5703e84867670Ac78f6b5b4b40A7c1","0xCca471B0d49c0d4835a5172Fd97ddDEA5C979100","0x4937A83Dc1Fa982e435aeB0dB33C90937d54E424","0x09e3d97A7CFbB116B416Dae284f119c1eC3Bd5ea"]
        for (market of allSupportedMarkets) {
            let cTokenInstance = await CToken.at(market);
            let compSpeed = await proxiedQstroller.compSpeeds(market);
            if (compSpeed <= 0) continue;
            let cTokenName = await cTokenInstance.name();
            console.log(`cTokenName: ${cTokenName}`)
            await cTokenInstance._setReserveFactor(reserveFactor);
            console.log(`reserveFactor is set to ${reserveFactor} for ${cTokenName} : ${cTokenInstance.address}`);
        }
        callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
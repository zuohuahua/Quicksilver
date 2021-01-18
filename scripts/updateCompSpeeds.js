const Qstroller = artifacts.require("Qstroller");
const Unitroller = artifacts.require("Unitroller");

const allTokens = [
    '0x824151251B38056d54A15E56B73c54ba44811aF8', // HT
    '0x0AD0bee939E00C54f57f21FBec0fBa3cDA7DEF58', // ELA
    '0x043aFB65e93500CE5BCbf5Bbb41FC1fDcE2B7518', // HFIL
    '0x2a2EF6d5EEF3896578fD0Cf070E38d55e734Aa8E', // ethUSDT
    '0xB16Df14C53C4bcfF220F4314ebCe70183dD804c0', // HUSD
    '0xFA1B8c6EE61A8cD85Ed4062D3529EEF088641539', // HPT(F)
    '0xD3a6503Ac690601E9bfcA8Bd46E57FbCBB767b5D', // ETH(F)
    '0x3eC4682D851D0B49Dd6625deabf08CE2c57AA1E8', // HBTC(F)
    '0x749E0198f12559E7606987F8e7bD3AA1DE6d236E', // HPT
    '0x033F8C30bb17B47f6f1f46F3A42Cc9771CCbCAAE', // ETH
    '0xF2a308d3Aea9bD16799A5984E20FDBfEf6c3F595', // HBTC
    '0xF0BdA6bC1BD6D4B5c422714447e67874d30B9c02', // HDOT(F)
    '0xCca471B0d49c0d4835a5172Fd97ddDEA5C979100', // HDOT
    '0x09e3d97A7CFbB116B416Dae284f119c1eC3Bd5ea', // HBCH
    '0x0DA389458C16a6F001A616560e285692a0ab615E', // HLTC(F)
    '0x4937A83Dc1Fa982e435aeB0dB33C90937d54E424'] // HLTC

const allCompSpeeds = [
    '500000000000000000', // HT
    '500000000000000000', // ELA
    '400000000000000000', // HFIL
    '0',                  // ethUSDT
    '1250000000000000000',// HUSD
    '0',                  // HPT(F)
    '0',                  // ETH(F
    '0',                  // HBTC
    '250000000000000000', // HPT
    '500000000000000000', // ETH
    '750000000000000000', // HBTC
    '0',                  // HDOT(F)
    '250000000000000000', // HDOT
    '350000000000000000', // HBCH
    '0',                  // HLTC(F)
    '250000000000000000'  // HLTC
]

module.exports = async function(callback) {
    try {
        let unitrollerInstance = await Unitroller.deployed();
        let proxiedQstroller = await Qstroller.at(unitrollerInstance.address);
        await proxiedQstroller._setCompSpeeds(allTokens, allCompSpeeds);
        callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
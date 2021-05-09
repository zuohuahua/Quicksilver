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
    '0x4937A83Dc1Fa982e435aeB0dB33C90937d54E424', // HLTC
    '0xAab0C9561D5703e84867670Ac78f6b5b4b40A7c1', // HUSD
    '0x7620D69D8afBaF927c14FF719FAeb1CE0560A4f7', // HBSV(F)
    '0x74F8D9B701bD4d8ee4ec812AF82C71EB67B9Ec75', // HBSV
    '0x28c395e3f37937aCDE226392254bb9c996655eb3',  // HXTZ(F)
    '0xfEA846A1284554036aC3191B5dFd786C0F4Db611', // HXTZ
    '0x92701DA6A28Ca70aA5Dfca2B8Ae2b4B8a22a0C11',  // HBSV
    '0x73Fa2931e060F7d43eE554fd1De7F61115fE1751',  // AAVE
    '0xAc9E3AE0C188eb583785246Fef37AEF9ea159fb7', // UNI
    '0x88962975FDE8C7805fE0f38b7c91C18f4d55bb40',  // SNX
    '0x5788C014D41cA706DE03969E283eE7b93827B7B1', // MDX
    '0x9E6f8357bae44C01ae69df807208c3f5E435BbeD'  // Link
]

const allCompSpeeds = [
    '234000000000000000', // HT
    '3900000000000000', // ELA
    '72150000000000000', // HFIL
    '0',                  // ethUSDT
    '1072500000000000000', // HUSD
    '0',                  // HPT(F)
    '0',                  // ETH(F
    '0',                  // HBTC
    '7020000000000000', // HPT
    '70200000000000000', // ETH
    '187200000000000000', // HBTC
    '0',                  // HDOT(F)
    '15990000000000000', // HDOT
    '7020000000000000', // HBCH
    '0',                  // HLTC(F)
    '13650000000000000', // HLTC
    '2113059000000000000', // HUSDT
    '0',                 // HBSV(F)
    '390000000000000', // HBSV
    '0',                  // HXTZ(F)
    '156000000000000',   // HXTZ
    '3120000000000000',    // PNEO
    '5070000000000000', // AAVE
    '7215000000000000', // UNI
    '2145000000000000', // SNX
    '78000000000000000',  // MDX
    '7215000000000000'  // Link
]

module.exports = async function(callback) {
    try {
        let sum = BigInt(0)
        for (let i = 0; i < allTokens.length; i++) {
            console.log(`${allTokens[i]} => ${allCompSpeeds[i]}`)
            sum += BigInt(allCompSpeeds[i])
        }
        console.log(`CompRate: ${sum}`)
        let unitrollerInstance = await Unitroller.deployed();
        let proxiedQstroller = await Qstroller.at(unitrollerInstance.address);
        await proxiedQstroller._setCompSpeeds(allTokens, allCompSpeeds);
        callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
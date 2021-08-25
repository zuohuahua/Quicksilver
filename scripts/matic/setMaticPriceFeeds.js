const ChainlinkOracle = artifacts.require("ChainlinkAdaptor");

const assets = [
    '0xD6DF932A45C0f255f85145f286eA0b292B21C90B', // AAVE
    '0xc2132d05d31c914a87c6611c10748aeb04b58e8f', // USDT
    '0x8f3cf7ad23cd3cadbd9735aff958023239c6a063', // DAI
    '0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6', // WBTC
    '0x7ceb23fd6bc0add59e62ac25578270cff1b9f619', // WETH
    '0x2791bca1f2de4661ed88a30c99a7a9449aa84174', // USDC
]

const priceSources = [
    '0x72484B12719E23115761D5DA1646945632979bB6',
    '0x0A6513e40db6EB1b165753AD52E80663aeA50545',
    '0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D',
    '0xDE31F8bFBD8c84b5360CFACCa3539B938dd78ae6',
    '0xF9680D99D6C9589e2a93a78A04A279e509205945',
    '0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7'
]

module.exports = async function(callback) {
    try {
        let chainlinkOracleInstance = await ChainlinkOracle.deployed();
        await chainlinkOracleInstance.setAssetSources(assets, priceSources);
        callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
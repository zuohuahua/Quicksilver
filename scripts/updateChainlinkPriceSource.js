const chainlinkAdaptor = artifacts.require("ChainlinkAdaptor")
let assetPriceSourceMapForTestnet = new Map([
    ['0x337610d27c682e347c9cd60bd4b3b107c9d34ddd', '0xEca2605f0BCF2BA5966372C99837b1F182d3D620'], // USDT
    ['0xd66c6b4f0be8ce5b39d52e0fd1344c389929b378', '0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7']  // ETH
])

let assetPriceSourceMapForMainnet = new Map([
    ['0x2170ed0880ac9a755fd29b2688956bd959f933f8', '0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e'], // ETH
    ['0xe9e7cea3dedca5984780bafc599bd69add087d56', '0xcBb98864Ef56E9042e7d2efef76141f15731B82f']  // BUSD
])

const argv = require('yargs').argv;

module.exports = async function(callback) {
    try {
        console.log(`argv> network=${argv.network}`);
        let assets = [...assetPriceSourceMapForTestnet.keys()];
        let priceSources = [...assetPriceSourceMapForTestnet.values()];
        if (argv.network == "bsc") {
            assets = [...assetPriceSourceMapForMainnet.keys()];
            priceSources = [...assetPriceSourceMapForMainnet.values()];
        }
        console.log("assets: ", assets);
        console.log("priceSources: ", priceSources);
        console.log("chainlinkAdaptor: ", chainlinkAdaptor.address);

        // let chainlinkAdaptorInstance = await chainlinkAdaptor.deployed();
        // await chainlinkAdaptorInstance.setAssetSources(assets, priceSources);
        callback();
    } catch (e) {
        console.log(e);
        callback(e);
    }
}
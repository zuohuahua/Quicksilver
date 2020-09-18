const MockPriceOracle = artifacts.require("MockPriceOracle");
const TetherToken = artifacts.require("TetherToken");
const InterestModel = artifacts.require("WhitePaperInterestRateModel");
const Comptroller = artifacts.require("Comptroller");
const sETH = artifacts.require("CEther");
const sUSDT = artifacts.require("CErc20");
const Unitroller = artifacts.require("Unitroller");

const maxAssets = 10;

module.exports = async function(deployer, network, accounts) {
    if (network == "development") {
        await deployer.deploy(Unitroller);
        await deployer.deploy(TetherToken, "1000000000000000", "Tether USD", "USDT", 6);
        await deployer.deploy(MockPriceOracle);
        await deployer.deploy(Comptroller).then(async function (instance) {
            await instance._setPriceOracle(MockPriceOracle.address);
            await instance._setMaxAssets(maxAssets);
            oracle = await instance.oracle();
        });
        let unitrollerInstance = await Unitroller.deployed();
        let comptrollerInstance = await Comptroller.deployed();

        await unitrollerInstance._setPendingImplementation(Comptroller.address);
        await comptrollerInstance._become(Unitroller.address);
        await deployer.deploy(InterestModel, "20000000000000000", "200000000000000000");
        await deployer.deploy(sETH, Comptroller.address, InterestModel.address, "10000000000000000000", "QuickSilver ETH", "sETH", 18, accounts[0])
        await deployer.deploy(sUSDT, TetherToken.address, Comptroller.address, InterestModel.address, "10000000", "QuickSilver USDT", "sUSDT", 18, accounts[0])

        let comptrollerContract = new web3.eth.Contract(comptrollerInstance.abi, comptrollerInstance.address);
        let supportETH = comptrollerContract.methods._supportMarket(sETH.address).encodeABI();
        await sendTx(accounts[0], comptrollerInstance.address, supportETH);

        let supportUSDT = comptrollerContract.methods._supportMarket(sUSDT.address).encodeABI();
        await sendTx(accounts[0], comptrollerInstance.address, supportUSDT);

        let allSupportedMarkets = await comptrollerInstance.getAllMarkets();
        console.log(allSupportedMarkets);
    }
};

function sendTx(fromAddress, toAddress, data) {
    web3.eth.sendTransaction({
        from: fromAddress,
        to: toAddress,
        gas: 6000000,
        gasPrice: 100000000,
        data: data
    });
}

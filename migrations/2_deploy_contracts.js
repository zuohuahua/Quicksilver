const MockPriceOracle = artifacts.require("MockPriceOracle");
const TetherToken = artifacts.require("TetherToken");
const InterestModel = artifacts.require("WhitePaperInterestRateModel");
const Comptroller = artifacts.require("Comptroller");
const sETH = artifacts.require("CEther");
const erc20Delegate = artifacts.require("CErc20Delegate");
const erc20Delegator = artifacts.require("CErc20Delegator");
//const CErc20Immutable = artifacts.require("CErc20Immutable");
const Unitroller = artifacts.require("Unitroller");
const CompToken = artifacts.require("Comp");
const Reservoir = artifacts.require("Reservoir");

const maxAssets = 10;

module.exports = async function(deployer, network, accounts) {
    if (network == "development" || network == "ethdev") {
        await deployer.deploy(Unitroller);
        await deployer.deploy(TetherToken, "1000000000000000", "Tether USD", "USDT", 6);
        await deployer.deploy(MockPriceOracle);
        await deployer.deploy(Comptroller);
        await deployer.deploy(CompToken, Unitroller.address);
        let compTokenInstance = await CompToken.deployed();
        let unitrollerInstance = await Unitroller.deployed();
        let comptrollerInstance = await Comptroller.deployed();

        await unitrollerInstance._setPendingImplementation(Comptroller.address);
        await comptrollerInstance._become(Unitroller.address);
        await deployer.deploy(InterestModel, "20000000000000000", "200000000000000000");
        await deployer.deploy(sETH, Unitroller.address, InterestModel.address, "10000000000000000000", "QuickSilver ETH", "sETH", 18, accounts[0]);
        //await deployer.deploy(CErc20Immutable, TetherToken.address, Unitroller.address, InterestModel.address, "10000000", "QuickSilver USDT", "sUSDT", 18, accounts[0]);
        await deployer.deploy(erc20Delegate);
        await deployer.deploy(erc20Delegator, TetherToken.address, Unitroller.address, InterestModel.address, "10000000", "QuickSilver USDT", "sUSDT", 18, accounts[0], erc20Delegate.address, "0x0");
        const sUSDT = erc20Delegator;
        // const sUSDT = CErc20Immutable;

        let compImpl = await unitrollerInstance.comptrollerImplementation();
        console.log("compImpl: " + compImpl);
        let proxiedComptrollerContract = new web3.eth.Contract(comptrollerInstance.abi, unitrollerInstance.address);

        let setPriceOracle = proxiedComptrollerContract.methods._setPriceOracle(MockPriceOracle.address).encodeABI();
        await sendTx(accounts[0], unitrollerInstance.address, setPriceOracle);

        let setMaxAssets = proxiedComptrollerContract.methods._setMaxAssets(maxAssets).encodeABI();
        await sendTx(accounts[0], unitrollerInstance.address, setMaxAssets);

        let supportETH = proxiedComptrollerContract.methods._supportMarket(sETH.address).encodeABI();
        await sendTx(accounts[0], unitrollerInstance.address, supportETH);

        let supportUSDT = proxiedComptrollerContract.methods._supportMarket(sUSDT.address).encodeABI();
        await sendTx(accounts[0], unitrollerInstance.address, supportUSDT);

        await proxiedComptrollerContract.methods._setCollateralFactor(sETH.address, 0.3e18.toString()).send({from: accounts[0]});
        await proxiedComptrollerContract.methods._setLiquidationIncentive(1.5e18.toString()).send({from: accounts[0]});
        await proxiedComptrollerContract.methods._addCompMarkets([sETH.address, sUSDT.address]).send({from: accounts[0], gas: 3000000});;
        await proxiedComptrollerContract.methods._setCompRate(0.5e18.toString()).send({from: accounts[0], gas: 3000000});;
        await proxiedComptrollerContract.methods._setCompToken(CompToken.address).send({from: accounts[0], gas: 3000000});

        let allSupportedMarkets = await proxiedComptrollerContract.methods.getAllMarkets().call();
        console.log(allSupportedMarkets);

        let tetherTokenInstance = await TetherToken.deployed();
        let tetherTokenContract = new web3.eth.Contract(tetherTokenInstance.abi, tetherTokenInstance.address);
        await tetherTokenContract.methods.approve(sUSDT.address, 1000000000).send({from: accounts[0]});
        let sUSDTInstance = await sUSDT.deployed();
        let sUSDTContract = new web3.eth.Contract(sUSDTInstance.abi, sUSDTInstance.address);
        await sUSDTContract.methods.mint(1000000000).send({from: accounts[0], gas: 8000000});
        let cash = await sUSDTContract.methods.totalSupply().call();
        console.log(cash);

        // await deployer.deploy(CompToken, accounts[0]);
        // await deployer.deploy(Reservoir, 1e18.toString(), CompToken.address, Unitroller.address);
        // let CompTokenInstance = await CompToken.deployed();
        // let CompTokenContract = new web3.eth.Contract(CompTokenInstance.abi, CompTokenInstance.address);
        // let totalSupply = await CompTokenContract.methods.totalSupply().call();
        // await CompTokenContract.methods.transfer(Reservoir.address, totalSupply).send({from: accounts[0]});

        let sETHInstance = await sETH.deployed();
        let sETHContract = new web3.eth.Contract(sETHInstance.abi, sETHInstance.address);
        await sETHContract.methods.mint().send({from: accounts[0], gas: 8000000, value: 1e18});

        await proxiedComptrollerContract.methods.refreshCompSpeeds().send({from: accounts[0], gas: 3000000});;

        await proxiedComptrollerContract.methods.enterMarkets([sETH.address, sUSDT.address]).send({from: accounts[0], gas: 8000000});
        let accountLiquidity = await proxiedComptrollerContract.methods.getAccountLiquidity(accounts[0]).call();
        console.log("Account Liquidity: ", accountLiquidity);

        await sUSDTContract.methods.borrow(1000000).send({from: accounts[0], gas: 8000000});
        let borrowBalance = await sUSDTContract.methods.borrowBalanceCurrent(accounts[0]).call();
        console.log("borrowBalance: ", borrowBalance);

        await proxiedComptrollerContract.methods.refreshCompSpeeds().send({from: accounts[0], gas: 3000000});;

        let accountLiquidity2 = await proxiedComptrollerContract.methods.getAccountLiquidity(accounts[0]).call();
        console.log("Account Liquidity: ", accountLiquidity2);
        await sUSDTContract.methods.borrow(1000000).send({from: accounts[0], gas: 8000000});
        let borrowBalance2 = await sUSDTContract.methods.borrowBalanceCurrent(accounts[0]).call();
        console.log("borrowBalance2: ", borrowBalance2);

        let compTotalSupply = await compTokenInstance.totalSupply();
        let compTotal = await compTotalSupply.toString();
        console.log("Comp Token total supply: ", compTotal);
        let compAmount = await compTokenInstance.balanceOf(accounts[0]);
        console.log("Comp Token Balance: ", await compAmount.toString());

        let compAccrued = await proxiedComptrollerContract.methods.compAccrued(accounts[0]).call();
        console.log("compAccrued: ", compAccrued);
        let compSpeeds = await proxiedComptrollerContract.methods.compSpeeds(sUSDT.address).call();
        console.log("compSpeeds: ", compSpeeds);
    }
};

function sendTx(fromAddress, toAddress, data) {
    web3.eth.sendTransaction({
        from: fromAddress,
        to: toAddress,
        gas: 6000000,
        gasPrice: 100000000,
        data: data,
        value: 0
    });
}

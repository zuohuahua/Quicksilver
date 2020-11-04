const SimplePriceOracle = artifacts.require("QsSimplePriceOracle");
const InterestModel = artifacts.require("WhitePaperInterestRateModel");
const Qstroller = artifacts.require("Qstroller");
const sELA = artifacts.require("CEther");
const erc20Delegate = artifacts.require("CErc20Delegate");
const erc20Delegator = artifacts.require("CErc20Delegator");
const Unitroller = artifacts.require("Unitroller");
const CompoundLens = artifacts.require("CompoundLens");
const QsPriceOracle = artifacts.require("QsPriceOracle");
const QsConfig = artifacts.require("QsConfig");

// Mock Tokens
const TetherToken = artifacts.require("TetherToken");
const HFILToken = artifacts.require("HFILToken");
const ETHToken = artifacts.require("ETHToken");
const ELAToken = artifacts.require("ELAToken");

// Parameters
const closeFactor = 0.5e18.toString();
const liquidationIncentive = 1.13e18.toString();
const compRate = 0.5e18.toString();
const reserveFactor = 0.2e18.toString();

const maxAssets = 10;

module.exports = async function(deployer, network) {
    await deployer.deploy(Unitroller);
    await deployer.deploy(Qstroller);
    await deployer.deploy(CompoundLens);
    await deployer.deploy(QsPriceOracle);
    await deployer.deploy(QsConfig);

    let unitrollerInstance = await Unitroller.deployed();
    let comptrollerInstance = await Qstroller.deployed();
    let admin = await comptrollerInstance.admin();
    console.log("admin: ", admin);

    await unitrollerInstance._setPendingImplementation(Qstroller.address);
    await comptrollerInstance._become(Unitroller.address);

    await deployer.deploy(InterestModel, "20000000000000000", "200000000000000000");

    let proxiedComptrollerContract = new web3.eth.Contract(comptrollerInstance.abi, unitrollerInstance.address);
    console.log("admin: ", await proxiedComptrollerContract.methods.admin().call());

    let setPriceOracle = proxiedComptrollerContract.methods._setPriceOracle(QsPriceOracle.address).encodeABI();
    await sendTx(admin, unitrollerInstance.address, setPriceOracle);
    console.log("Done to set price oracle.", await proxiedComptrollerContract.methods.oracle().call());

    let setQsConfig = proxiedComptrollerContract.methods._setQsConfig(QsConfig.address).encodeABI();
    await sendTx(admin, unitrollerInstance.address, setQsConfig);
    console.log("Done to set quick silver config.", await  proxiedComptrollerContract.methods.qsConfig().call());

    let setMaxAssets = proxiedComptrollerContract.methods._setMaxAssets(maxAssets).encodeABI();
    await sendTx(admin, unitrollerInstance.address, setMaxAssets);
    console.log("Done to set max assets.", await proxiedComptrollerContract.methods.maxAssets().call());

    await proxiedComptrollerContract.methods._setLiquidationIncentive(liquidationIncentive).send({from: admin, gas: 3000000});
    console.log("Done to set liquidation incentive.");
    let incentive = await proxiedComptrollerContract.methods.liquidationIncentiveMantissa().call();
    console.log("New incentive: ", incentive);

    await proxiedComptrollerContract.methods._setCompRate(compRate).send({from: admin, gas: 3000000});
    console.log("Done to set comp rate with value: ", await proxiedComptrollerContract.methods.compRate().call());

    await proxiedComptrollerContract.methods._setCloseFactor(closeFactor).send({from: admin, gas: 3000000});
    console.log("Done to set close factor with value: ", await proxiedComptrollerContract.methods.closeFactorMantissa().call());

    if (network == "development" || network == "eladev" || network == "elalocal" || network == "ethlocal" || network == "ethdev") {
        let compImpl = await unitrollerInstance.comptrollerImplementation();
        console.log("compImpl: " + compImpl);

        await deployer.deploy(SimplePriceOracle);

        if (network == "eladev" || network == "elalocal") {
            await deployer.deploy(sELA, Unitroller.address, InterestModel.address, "20000000000000000", "QuickSilver ELA", "sELA", 18, admin);
            let supportELA = proxiedComptrollerContract.methods._supportMarket(sELA.address).encodeABI();
            await sendTx(admin, unitrollerInstance.address, supportELA);
            console.log("Done to support market: ", sELA.address);
            let elaCollateralFactor = 0.15e18.toString();
            await proxiedComptrollerContract.methods._setCollateralFactor(sELA.address, elaCollateralFactor).send({from: admin, gas: 3000000});
            console.log("Done to set collateral factor %s for %s", elaCollateralFactor, sELA.address);

            // Handle Mocked ETH
            await deployer.deploy(ETHToken);
            await deployer.deploy(erc20Delegate);
            await deployer.deploy(erc20Delegator, ETHToken.address, Unitroller.address, InterestModel.address, "20000000000000000", "QuickSilver ETH", "sETH", 18, admin, erc20Delegate.address, "0x0");
            const sETHElastos = erc20Delegator;
            const sETHElastosInstance = await sETHElastos.deployed();
            let proxiedETHElastos = new web3.eth.Contract(sETHElastosInstance.abi, sETHElastos.address);
            await proxiedETHElastos.methods._setReserveFactor(reserveFactor).send({from: admin, gas: 3000000});
            let supportETHElastos = proxiedComptrollerContract.methods._supportMarket(sETHElastos.address).encodeABI();
            await sendTx(admin, unitrollerInstance.address, supportETHElastos);
            let ETHElastosCollateralFactor = 0.5e18.toString();
            await proxiedComptrollerContract.methods._setCollateralFactor(sETHElastos.address, ETHElastosCollateralFactor).send({from: admin, gas: 3000000});
            console.log("Done to set collateral factor %s for %s", ETHElastosCollateralFactor, sETHElastos.address);
        }

        if (network == "ethdev" || network == "ethlocal") {
            await deployer.deploy(sELA, Unitroller.address, InterestModel.address, "20000000000000000", "QuickSilver ETH", "sETH", 18, admin);
            let supportELA = proxiedComptrollerContract.methods._supportMarket(sELA.address).encodeABI();
            await sendTx(admin, unitrollerInstance.address, supportELA);
            console.log("Done to support market: ", sELA.address);
            let elaCollateralFactor = 0.15e18.toString();
            await proxiedComptrollerContract.methods._setCollateralFactor(sELA.address, elaCollateralFactor).send({from: admin, gas: 3000000});
            console.log("Done to set collateral factor %s for %s", elaCollateralFactor, sELA.address);

            // Handle Mocked ETH
            await deployer.deploy(ELAToken);
            await deployer.deploy(erc20Delegate);
            await deployer.deploy(erc20Delegator, ELAToken.address, Unitroller.address, InterestModel.address, "20000000000000000", "QuickSilver ELA on ETH", "sELA", 18, admin, erc20Delegate.address, "0x0");
            const sELAElastos = erc20Delegator;
            const sELAElastosInstance = await sELAElastos.deployed();
            let proxiedELAElastos = new web3.eth.Contract(sELAElastosInstance.abi, sELAElastos.address);
            await proxiedELAElastos.methods._setReserveFactor(reserveFactor).send({from: admin, gas: 3000000});
            let supportELAElastos = proxiedComptrollerContract.methods._supportMarket(sELAElastos.address).encodeABI();
            await sendTx(admin, unitrollerInstance.address, supportELAElastos);
            let ELAEthCollateralFactor = 0.5e18.toString();
            await proxiedComptrollerContract.methods._setCollateralFactor(sELAElastos.address, ELAEthCollateralFactor).send({from: admin, gas: 3000000});
            console.log("Done to set collateral factor %s for %s", ELAEthCollateralFactor, sELAElastos.address);
        }


        // Handle Mocked USDT
        await deployer.deploy(TetherToken, "1000000000000000", "Tether USD", "USDT", 6);
        await deployer.deploy(erc20Delegate);
        await deployer.deploy(erc20Delegator, TetherToken.address, Unitroller.address, InterestModel.address, "20000", "QuickSilver USDT", "sUSDT", 18, admin, erc20Delegate.address, "0x0");
        const sUSDT = erc20Delegator;
        const sUSDTInstance = await sUSDT.deployed();
        let proxiedSUSDT = new web3.eth.Contract(sUSDTInstance.abi, erc20Delegator.address);
        await proxiedSUSDT.methods._setReserveFactor(reserveFactor).send({from: admin, gas: 3000000});
        let supportUSDT = proxiedComptrollerContract.methods._supportMarket(sUSDT.address).encodeABI();
        await sendTx(admin, unitrollerInstance.address, supportUSDT);
        let usdtCollateralFactor = 0.8e18.toString();
        await proxiedComptrollerContract.methods._setCollateralFactor(sUSDT.address, usdtCollateralFactor).send({from: admin, gas: 3000000});
        console.log("Done to set collateral factor %s for %s", usdtCollateralFactor, sUSDT.address);

        // Handle Mocked HFIL
        await deployer.deploy(HFILToken);
        await deployer.deploy(erc20Delegate);
        await deployer.deploy(erc20Delegator, HFILToken.address, Unitroller.address, InterestModel.address, "20000000000000000", "QuickSilver HFIL", "sHFIL", 18, admin, erc20Delegate.address, "0x0");

        const sHFIL = erc20Delegator;
        const sHFILInstance = await sHFIL.deployed();
        let proxiedHFIL = new web3.eth.Contract(sHFILInstance.abi, sHFIL.address);
        await proxiedHFIL.methods._setReserveFactor(reserveFactor).send({from: admin, gas: 3000000});

        let supportHFIL = proxiedComptrollerContract.methods._supportMarket(sHFIL.address).encodeABI();
        await sendTx(admin, unitrollerInstance.address, supportHFIL);
        let hfilCollateralFactor = 0.5e18.toString();
        await proxiedComptrollerContract.methods._setCollateralFactor(sHFIL.address, hfilCollateralFactor).send({from: admin, gas: 3000000});
        console.log("Done to set collateral factor %s for HFIL %s", hfilCollateralFactor, sHFIL.address);


        let allSupportedMarkets = await proxiedComptrollerContract.methods.getAllMarkets().call();
        console.log(allSupportedMarkets);

        await proxiedComptrollerContract.methods._setPriceOracle(SimplePriceOracle.address).send({from: admin, gas: 3000000});
        console.log("Done to update price oracle.");
    }

    if (network == "kovan" || network == "ropsten") {
        await deployer.deploy(TetherToken, "1000000000000000", "Tether USD", "USDT", 6);

        await deployer.deploy(erc20Delegate);
        await deployer.deploy(erc20Delegator, TetherToken.address, Unitroller.address, InterestModel.address, "10000000", "QuickSilver USDT", "sUSDT", 18, admin, erc20Delegate.address, "0x0");
        const sUSDT = erc20Delegator;

        let supportUSDT = proxiedComptrollerContract.methods._supportMarket(sUSDT.address).encodeABI();
        await sendTx(admin, unitrollerInstance.address, supportUSDT);
        console.log("Done to support market: ", sUSDT.address);

        let allSupportedMarkets = await proxiedComptrollerContract.methods.getAllMarkets().call();
        console.log("allSupportedMarkets: ", allSupportedMarkets);
    }

    if (network == "elaeth") {
        let allSupportedMarkets = await proxiedComptrollerContract.methods.getAllMarkets().call();
        console.log("allSupportedMarkets: ", allSupportedMarkets);
    }
};

function sendTx(fromAddress, toAddress, data) {
    web3.eth.sendTransaction({
        from: fromAddress,
        to: toAddress,
        gas: 6000000,
        gasPrice: 5000000000,
        data: data,
        value: 0
    });
}

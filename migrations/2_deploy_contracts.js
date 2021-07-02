const SimplePriceOracle = artifacts.require("QsSimplePriceOracle");
const QsPriceOracleV2 = artifacts.require("QsPriceOracleV2");
const InterestModel = artifacts.require("HecoJumpInterestModel");
const Qstroller = artifacts.require("Qstroller");
const sELA = artifacts.require("CEther");
const erc20Delegate = artifacts.require("CErc20Delegate");
const erc20Delegator = artifacts.require("CErc20Delegator");
const Unitroller = artifacts.require("Unitroller");
const CompoundLens = artifacts.require("CompoundLens");
const ChainLinkPriceOracle = artifacts.require("ChainlinkAdaptor");
const QsConfig = artifacts.require("QsConfig");
const Maximillion = artifacts.require("Maximillion");

// Mock Tokens
const TetherToken = artifacts.require("TetherToken");
const HFILToken = artifacts.require("HFILToken");
const ETHToken = artifacts.require("ETHToken");
const ELAToken = artifacts.require("ELAToken");

// Parameters
const closeFactor = 0.5e18.toString();
const liquidationIncentive = 1.13e18.toString();
const reserveFactor = 0.3e18.toString();

const maxAssets = 10;

let addressFactory = {};
module.exports = async function(deployer, network) {
    await deployer.deploy(Unitroller);
    await deployer.deploy(Qstroller);
    await deployer.deploy(CompoundLens);
    await deployer.deploy(QsConfig, "0x0000000000000000000000000000000000000000");

    addressFactory["Qstroller"] = Unitroller.address;
    addressFactory["QsConfig"] = QsConfig.address;
    addressFactory["CompoundLens"] = CompoundLens.address;

    let unitrollerInstance = await Unitroller.deployed();
    let qstrollerInstance = await Qstroller.deployed();
    let admin = await qstrollerInstance.admin();
    console.log("admin: ", admin);

    await unitrollerInstance._setPendingImplementation(Qstroller.address);
    await qstrollerInstance._become(Unitroller.address);

    const baseRatePerYear = 0.03e18.toString();
    const multiplierPerYear = 0.3e18.toString();
    const jumpMultiplierPerYear = 5e18.toString();
    const kink = 0.95e18.toString();
    const reserveFactor = 0.2e18.toString();
    await deployer.deploy(InterestModel, baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink);

    let proxiedQstroller = await Qstroller.at(Unitroller.address);

    await proxiedQstroller._setQsConfig(QsConfig.address);
    console.log("Done to set quick silver config.", await  proxiedQstroller.qsConfig());

    await proxiedQstroller._setMaxAssets(maxAssets);
    let result = await proxiedQstroller.maxAssets();
    console.log("Done to set max assets.", result.toString());

    await proxiedQstroller._setLiquidationIncentive(liquidationIncentive);
    console.log("Done to set liquidation incentive.");
    let incentive = await proxiedQstroller.liquidationIncentiveMantissa();
    console.log("New incentive: ", incentive.toString());

    await proxiedQstroller._setCloseFactor(closeFactor);
    result = await proxiedQstroller.closeFactorMantissa();
    console.log("Done to set close factor with value: ", result.toString());

    if (network == "development" || network == "eladev" || network == "elalocal" || network == "ethlocal" || network == "ethdev") {
        let compImpl = await unitrollerInstance.comptrollerImplementation();
        console.log("compImpl: " + compImpl);

        await deployer.deploy(SimplePriceOracle);

        if (network == "eladev" || network == "elalocal") {
            await deployer.deploy(sELA, Unitroller.address, InterestModel.address, 0.02e18.toString(), "QuickSilver ELA", "sELA", 18, admin);
            await proxiedQstroller._supportMarket(sELA.address);
            console.log("Done to support market: ", sELA.address);
            let elaCollateralFactor = 0.15e18.toString();
            await proxiedQstroller._setCollateralFactor(sELA.address, elaCollateralFactor);
            console.log("Done to set collateral factor %s for %s", elaCollateralFactor, sELA.address);
            addressFactory["sELA"] = sELA.address;
            await deployer.deploy(Maximillion, sELA.address);
            addressFactory["Maximillion"] = Maximillion.address;

            // Handle Mocked ETH
            await deployer.deploy(ETHToken);
            await deployer.deploy(erc20Delegate);
            await deployer.deploy(erc20Delegator, ETHToken.address, Unitroller.address, InterestModel.address, 0.02e18.toString(), "QuickSilver ETH on ELA", "sElaETH", 18, admin, erc20Delegate.address, "0x0");
            const sETHElastosInstance = await erc20Delegator.deployed();
            await sETHElastosInstance._setReserveFactor(reserveFactor);
            await proxiedQstroller._supportMarket(erc20Delegator.address)
            let ETHElastosCollateralFactor = 0.5e18.toString();
            await proxiedQstroller._setCollateralFactor(erc20Delegator.address, ETHElastosCollateralFactor)
            console.log("Done to set collateral factor %s for %s", ETHElastosCollateralFactor, erc20Delegator.address);
            addressFactory["ETH"] = ETHToken.address;
            addressFactory["sETH"] = erc20Delegator.address;
        }

        if (network == "ethdev" || network == "ethlocal") {
            await deployer.deploy(sELA, Unitroller.address, InterestModel.address, 0.02e18.toString(), "QuickSilver ETH", "sETH", 18, admin);
            await proxiedQstroller._supportMarket(sELA.address);
            console.log("Done to support market: ", sELA.address);
            let elaCollateralFactor = 0.5e18.toString();
            await proxiedQstroller._setCollateralFactor(sELA.address, elaCollateralFactor)
            console.log("Done to set collateral factor %s for %s", elaCollateralFactor, sELA.address);
            addressFactory["sETH"] = sELA.address;
            await deployer.deploy(Maximillion, sELA.address);
            addressFactory["Maximillion"] = Maximillion.address;

            // Handle Mocked ETH
            await deployer.deploy(ELAToken);
            await deployer.deploy(erc20Delegate);
            await deployer.deploy(erc20Delegator, ELAToken.address, Unitroller.address, InterestModel.address, 0.02e18.toString(), "QuickSilver ELA on ETH", "sEthELA", 18, admin, erc20Delegate.address, "0x0");
            const sELAElastosInstance = await erc20Delegator.deployed();
            await sELAElastosInstance._setReserveFactor(reserveFactor);
            await proxiedQstroller._supportMarket(erc20Delegator.address)
            let ELAEthCollateralFactor = 0.15e18.toString();
            proxiedQstroller._setCollateralFactor(erc20Delegator.address, ELAEthCollateralFactor);
            console.log("Done to set collateral factor %s for %s", ELAEthCollateralFactor, erc20Delegator.address);
            addressFactory["ELA"] = ELAToken.address;
            addressFactory["sELA"] = erc20Delegator.address;
        }


        // Handle Mocked USDT
        await deployer.deploy(TetherToken, "1000000000000000", "Tether USD", "USDT", 6);
        await deployer.deploy(erc20Delegate);
        await deployer.deploy(erc20Delegator, TetherToken.address, Unitroller.address, InterestModel.address, 0.02e6.toString(), "QuickSilver USDT", "sUSDT", 18, admin, erc20Delegate.address, "0x0");
        const sUSDTInstance = await erc20Delegator.deployed();
        await sUSDTInstance._setReserveFactor(reserveFactor);
        await proxiedQstroller._supportMarket(erc20Delegator.address)
        let usdtCollateralFactor = 0.8e18.toString();
        await proxiedQstroller._setCollateralFactor(erc20Delegator.address, usdtCollateralFactor);
        console.log("Done to set collateral factor %s for %s", usdtCollateralFactor, erc20Delegator.address);
        addressFactory["USDT"] = TetherToken.address;
        addressFactory["sUSDT"] = erc20Delegator.address;

        // Handle Mocked HFIL
        await deployer.deploy(HFILToken);
        await deployer.deploy(erc20Delegate);
        await deployer.deploy(erc20Delegator, HFILToken.address, Unitroller.address, InterestModel.address, 0.02e18.toString(), "QuickSilver HFIL", "sHFIL", 18, admin, erc20Delegate.address, "0x0");

        // const sHFIL = erc20Delegator;
        const sHFILInstance = await erc20Delegator.deployed();
        await sHFILInstance._setReserveFactor(reserveFactor);

        await proxiedQstroller._supportMarket(erc20Delegator.address);
        let hfilCollateralFactor = 0.5e18.toString();
        await proxiedQstroller._setCollateralFactor(erc20Delegator.address, hfilCollateralFactor);
        let hfilCollateralFactorAfter = await proxiedQstroller.markets(erc20Delegator.address);
        console.log("Done to set collateral factor %s for HFIL %s", hfilCollateralFactorAfter.collateralFactorMantissa, erc20Delegator.address);
        addressFactory["HFIL"] = HFILToken.address;
        addressFactory["sHFIL"] = erc20Delegator.address;

        let allSupportedMarkets = await proxiedQstroller.getAllMarkets();
        console.log(allSupportedMarkets);

        await proxiedQstroller._setPriceOracle(SimplePriceOracle.address);
        console.log("Done to update price oracle.");
    }

    if (network == "ropsten") {
        await deployer.deploy(TetherToken, "1000000000000000", "Tether USD", "USDT", 6);

        await deployer.deploy(erc20Delegate);
        await deployer.deploy(erc20Delegator, TetherToken.address, Unitroller.address, InterestModel.address, 0.02e6.toString(), "QuickSilver USDT", "sUSDT", 18, admin, erc20Delegate.address, "0x0");

        await proxiedQstroller._supportMarket(erc20Delegator.address);
        console.log("Done to support market: ", erc20Delegator.address);

        let allSupportedMarkets = await proxiedQstroller.getAllMarkets();
        console.log("allSupportedMarkets: ", allSupportedMarkets);
    }

    if (network == "elatest") {
        const ethOnEla = "0x23f1528e61d0af04faa7cff8c7ce9046d9130789";
        const filOnEla = "0xd3f1be7f74d25f39184d2d0670966e2e837562e3";
        const usdtOnEla = "0xa7daaf45ae0b2e567eb563fb57ea9cfffdfd73dd";
        const usdcOnEla = "0x9064a6dae8023033e5119a3a3bdff65736cfe9e2"

        // Handle ethOnEla
        await deployer.deploy(erc20Delegate);
        await deployer.deploy(erc20Delegator, ethOnEla, Unitroller.address, InterestModel.address, 0.02e18.toString(), "QuickSilver ETH on Elastos", "sElaETH", 18, admin, erc20Delegate.address, "0x0");
        const sETHInstance = await erc20Delegator.deployed();
        await sETHInstance._setReserveFactor(reserveFactor);

        let qsControllerInstance = await Qstroller.at(unitrollerInstance.address);
        await qsControllerInstance._supportMarket(sETHInstance.address);
        console.log("Done to support market sETH: ", sETHInstance.address);

        let ethOnElaCollateralFactor = 0.5e18.toString();
        await qsControllerInstance._setCollateralFactor(sETHInstance.address, ethOnElaCollateralFactor);
        console.log("Done to set collateral factor %s for sETH %s", ethOnElaCollateralFactor, sETHInstance.address);
        addressFactory["ETH"] = ethOnEla;
        addressFactory["sETH"] = erc20Delegator.address;

        // Handle filOnEla
        await deployer.deploy(erc20Delegate);
        await deployer.deploy(erc20Delegator, filOnEla, Unitroller.address, InterestModel.address, 0.02e18.toString(), "QuickSilver ethHFIL", "sEthHFIL", 18, admin, erc20Delegate.address, "0x0");
        const sHFILInstance = await erc20Delegator.deployed();
        await sHFILInstance._setReserveFactor(reserveFactor);

        await qsControllerInstance._supportMarket(sHFILInstance.address);
        console.log("Done to support market sHFIL: ", sHFILInstance.address);

        let hfilOnElaCollateralFactor = 0.5e18.toString();
        await qsControllerInstance._setCollateralFactor(sHFILInstance.address, hfilOnElaCollateralFactor);
        console.log("Done to set collateral factor %s for sHFIL %s", hfilOnElaCollateralFactor, sHFILInstance.address);
        addressFactory["HFIL"] = filOnEla;
        addressFactory["sHFIL"] = erc20Delegator.address;

        // Handle usdtOnEla
        await deployer.deploy(erc20Delegate);
        await deployer.deploy(erc20Delegator, usdtOnEla, Unitroller.address, InterestModel.address, 0.02e6.toString(), "QuickSilver ethUSDT", "sEthUSDT", 18, admin, erc20Delegate.address, "0x0");
        const sUSDTInstance = await erc20Delegator.deployed();
        await sUSDTInstance._setReserveFactor(reserveFactor);

        await qsControllerInstance._supportMarket(sUSDTInstance.address);
        console.log("Done to support market sUSDT: ", sUSDTInstance.address);

        let usdtOnElaCollateralFactor = 0.5e18.toString();
        await qsControllerInstance._setCollateralFactor(sUSDTInstance.address, usdtOnElaCollateralFactor);
        console.log("Done to set collateral factor %s for sUSDT %s", usdtOnElaCollateralFactor, sUSDTInstance.address);
        addressFactory["USDT"] = usdtOnEla;
        addressFactory["sUSDT"] = erc20Delegator.address;

        // Handle usdcOnEla
        await deployer.deploy(erc20Delegate);
        await deployer.deploy(erc20Delegator, usdcOnEla, Unitroller.address, InterestModel.address, 0.02e6.toString(), "QuickSilver ethUSDC", "sEthUSDC", 18, admin, erc20Delegate.address, "0x0");
        const sUSDCInstance = await erc20Delegator.deployed();
        await sUSDCInstance._setReserveFactor(reserveFactor);

        await qsControllerInstance._supportMarket(sUSDCInstance.address);
        console.log("Done to support market sUSDC: ", sUSDCInstance.address);

        let usdcOnElaCollateralFactor = 0.5e18.toString();
        await qsControllerInstance._setCollateralFactor(sUSDCInstance.address, usdcOnElaCollateralFactor);
        console.log("Done to set collateral factor %s for sUSDC %s", usdcOnElaCollateralFactor, sUSDCInstance.address);
        addressFactory["USDC"] = usdcOnEla;
        addressFactory["sUSDC"] = erc20Delegator.address;

        // handle native token ELA
        await deployer.deploy(sELA, Unitroller.address, InterestModel.address, 0.02e18.toString(), "QuickSilver ELA", "sELA", 18, admin);
        await qsControllerInstance._supportMarket(sELA.address);
        console.log("Done to support market sELA: ", sELA.address);
        let elaCollateralFactor = 0.15e18.toString();
        await qsControllerInstance._setCollateralFactor(sELA.address, elaCollateralFactor);
        console.log("Done to set collateral factor %s for sELA %s", elaCollateralFactor, sELA.address);
        addressFactory["sELA"] = sELA.address;
        await deployer.deploy(Maximillion, sELA.address);
        addressFactory["Maximillion"] = Maximillion.address;
    }
    if (network == "elaeth") {
        let allSupportedMarkets = await proxiedQstroller.getAllMarkets();
        console.log("allSupportedMarkets: ", allSupportedMarkets);
    }

    if (network == "hecotest" || network == "heco") {
        await deployer.deploy(sELA, Unitroller.address, InterestModel.address, 0.02e18.toString(), "Filda HT", "fHT", 18, admin);
        await proxiedQstroller._supportMarket(sELA.address);
        console.log("Done to support market fHT: ", sELA.address);
        let htCollateralFactor = 0.15e18.toString();
        await proxiedQstroller._setCollateralFactor(sELA.address, htCollateralFactor);
        console.log("Done to set collateral factor %s for fHT %s", htCollateralFactor, sELA.address);
        addressFactory["fHT"] = sELA.address;
        await deployer.deploy(Maximillion, sELA.address);
        addressFactory["Maximillion"] = Maximillion.address;
    }

    if (network == "arbitrum" || network == "arbitrumtest") {
        await deployer.deploy(QsPriceOracleV2);
        let proxiedQstroller = await Qstroller.at(Unitroller.address);
        await proxiedQstroller._setPriceOracle(QsPriceOracleV2.address);
        console.log("Done to set price oracle.", await proxiedQstroller.oracle());
        addressFactory["QsPriceOracleV2"] = QsPriceOracleV2.address;
        await deployer.deploy(sELA, Unitroller.address, InterestModel.address, 0.02e18.toString(), "Filda ETH", "fETH", 18, admin);
        await proxiedQstroller._supportMarket(sELA.address);
        console.log("Done to support market fETH: ", sELA.address);
        let htCollateralFactor = 0.8e18.toString();
        await proxiedQstroller._setCollateralFactor(sELA.address, htCollateralFactor);
        console.log("Done to set collateral factor %s for fETH %s", htCollateralFactor, sELA.address);
        addressFactory["fETH"] = sELA.address;
        await deployer.deploy(Maximillion, sELA.address);
        addressFactory["Maximillion"] = Maximillion.address;
    }

    if (network == "bsctest" || network == "bsc") {
        let bnbPriceSource = "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526";
        if (network == "bsc") {
            bnbPriceSource = "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE";
        }
        await deployer.deploy(ChainLinkPriceOracle, bnbPriceSource);
        let proxiedQstroller = await Qstroller.at(Unitroller.address);
        await proxiedQstroller._setPriceOracle(ChainLinkPriceOracle.address);
        console.log("Done to set price oracle.", await proxiedQstroller.oracle());
        addressFactory["ChainLinkPriceOracle"] = ChainLinkPriceOracle.address;
        await deployer.deploy(sELA, Unitroller.address, InterestModel.address, 0.02e18.toString(), "Filda BNB", "fBNB", 18, admin);
        await proxiedQstroller._supportMarket(sELA.address);
        console.log("Done to support market fBNB: ", sELA.address);
        let htCollateralFactor = 0.8e18.toString();
        await proxiedQstroller._setCollateralFactor(sELA.address, htCollateralFactor);
        console.log("Done to set collateral factor %s for fBNB %s", htCollateralFactor, sELA.address);
        addressFactory["fBNB"] = sELA.address;
        await deployer.deploy(Maximillion, sELA.address);
        addressFactory["Maximillion"] = Maximillion.address;
    }
    console.log("================= Copy and record below addresses ==============")
    console.log(addressFactory);
};

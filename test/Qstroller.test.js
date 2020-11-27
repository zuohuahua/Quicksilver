const Qstroller = artifacts.require("Qstroller");
const Unitroller = artifacts.require("Unitroller");
const sELA = artifacts.require("CEther");

contract("Qstroller", async accounts => {
    it("should set governance token properly", async () => {
        let sElaInstance = await sELA.deployed();
        let unitrollerInstance = await Unitroller.deployed();
        let proxiedQstroller = await Qstroller.at(unitrollerInstance.address);

        let allMarkets = await proxiedQstroller.getAllMarkets();
        console.log(allMarkets);
        let depositAmount = web3.utils.toWei('0.1', 'ether');
        // await sElaInstance.mint({value:depositAmount});
        let supplyStateAfterMint = await proxiedQstroller.compSupplyState(sElaInstance.address);
        assert.equal(supplyStateAfterMint.index.toString(), 0);
        assert.equal(supplyStateAfterMint.block.toString(), 0);
        await proxiedQstroller._setCompSpeeds(allMarkets, [0.2e18.toString(), 0.1e18.toString(), 0.1e18.toString(), 0.1e18.toString()]);

        await Promise.all(allMarkets.map(async (market) => {
            let supply = await proxiedQstroller.compSupplyState(market);
            assert.equal(supply.index.toString(), 1e36)
            let compSpeed = await proxiedQstroller.compSpeeds(market);
            console.log(`compSpeed: ${compSpeed}`);
            let marketObject = await proxiedQstroller.markets(market)
            assert.equal(marketObject.isComped, true);
        }))
        await sElaInstance.mint({value:depositAmount});
        blockNumber = await proxiedQstroller.getBlockNumber();
        let supplyTokens = await sElaInstance.totalSupply();
        assert.equal(supplyTokens, 5e18.toString());
        await sElaInstance.mint({from: accounts[1], value:depositAmount});
        await sElaInstance.mint({value:depositAmount});
        let compAmount = await proxiedQstroller.compAccrued(accounts[0]);
        assert.equal(compAmount, 0.3e18.toString());
    });
})
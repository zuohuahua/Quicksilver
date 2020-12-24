const cEther = artifacts.require("CEther");
const priceOracle = artifacts.require("QsPriceOracle");

contract("cEther", async accounts => {
    it("should get price properly", async () => {
        let priceOracleInstance = await priceOracle.deployed();
        let cEtherInstance = await cEther.deployed();

        let price = await priceOracleInstance.getUnderlyingPrice(cEtherInstance.address);
        console.log(`price: ${price}`)
        assert.equal(price, 1e18);

    })
})
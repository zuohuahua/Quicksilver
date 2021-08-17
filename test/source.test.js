const Target = artifacts.require("Target");
const Source = artifacts.require("Source");

module.exports = async (deployer) => {
    let instanceS = await Source.deployed();
    let instanceT = await Target.at(instanceS.address);
    await instanceT.setX(2)
    let x = await instanceT.getX();
    console.log("当前x的值为:",x.toNumber())
    x = await instanceT.getX();
    console.log("当前x的值为:",x.toNumber())
};
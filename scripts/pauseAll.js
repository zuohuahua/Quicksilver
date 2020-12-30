const Qstroller = artifacts.require("Qstroller")
const Unitroller = artifacts.require("Unitroller")

const argv = require('yargs').argv

module.exports = async function(callback) {
    try {
        console.log(`argv> fToken=${argv.fToken}, paused=${argv.paused}`)

        let qsControllerInstance = await Qstroller.at(Unitroller.address)

        await qsControllerInstance._setMintPaused(argv.fToken, argv.paused)
        console.log("MintPaused: ", await qsControllerInstance.mintGuardianPaused(argv.fToken))

        await qsControllerInstance._setBorrowPaused(argv.fToken, argv.paused)
        console.log("BorrowPaused: ", await qsControllerInstance.borrowGuardianPaused(argv.fToken))

        await qsControllerInstance._setTransferPaused(argv.paused)
        console.log("TransferPaused: ", await qsControllerInstance.transferGuardianPaused())

        await qsControllerInstance._setSeizePaused(argv.paused)
        console.log("SeizePaused: ", await qsControllerInstance.seizeGuardianPaused())

        callback()
    } catch (e) {
        callback(e)
        console.log(e)
    }
}

## How to support new token
truffle exec scripts/deployCErc20.js --token {token address} --collateralFactor {collateralFactor for this token} --network {target network}

example: truffle exec scripts/deployCErc20.js --token 0x9893efec0c06a5c82ed76a726d12ee469fe449d8 --collateralFactor 150000000000000000 --network hecotest

## How to pause protocol running
### Pause
truffle exec scripts/pauseAll.js --fToken 0x649AEBca1AF302f78533E7059A1B387FB8DACDd8 --paused 1 --network hecotest

### Unpause
truffle exec scripts/pauseAll.js --fToken 0x649AEBca1AF302f78533E7059A1B387FB8DACDd8 --paused 0 --network hecotest
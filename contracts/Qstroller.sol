pragma solidity ^0.5.16;

import "./compound/Comptroller.sol";
import "./compound/EIP20Interface.sol";
import "./QsConfig.sol";

contract Qstroller is Comptroller {
    QsConfig public qsConfig;

    function _setQsConfig(QsConfig _qsConfig) public {
        require(msg.sender == admin, "Only admin can set quick silver configuration data.");

        qsConfig = _qsConfig;
    }

    /**
     * @notice Sets new governance token distribution speed
     * @dev Admin function to set new token distribution speed
     */
    function _setCompSpeeds(address[] memory _allMarkets, uint[] memory _compSpeeds) public {
        // Check caller is admin
        require(msg.sender == admin, "Only admin can update token distribution");
        
        require(_allMarkets.length == _compSpeeds.length, "Incomplete parameter");
        require(allMarkets.length == _allMarkets.length, "Must update token distribution within one transaction");

        for (uint i = 0; i < _allMarkets.length; i++) {
            compSpeeds[_allMarkets[i]] = _compSpeeds[i];
        }
    }


    function refreshCompSpeeds() public {
        require(!qsConfig.compSpeedGuardianPaused(), "compSpeed is paused");
        require(msg.sender == tx.origin, "only externally owned accounts may refresh speeds");

        refreshCompSpeedsInternal();
    }

    function getCompAddress() public view returns (address) {
        return qsConfig.compToken();
    }
    
    function calculateSeizeTokenAllocation(uint _seizeTokenAmount) public view returns(uint liquidatorAmount, uint safetyVaultAmount) {
        return qsConfig.calculateSeizeTokenAllocation(_seizeTokenAmount, liquidationIncentiveMantissa);
    }
    
    function transferComp(address user, uint userAccrued, uint threshold) internal returns (uint) {
        if (userAccrued >= threshold && userAccrued > 0) {
            EIP20Interface comp = EIP20Interface(getCompAddress());
            uint compRemaining = comp.balanceOf(address(this));
            if (userAccrued <= compRemaining) {
                comp.transfer(user, userAccrued);
                return 0;
            }
        }
        return userAccrued;
    }
}
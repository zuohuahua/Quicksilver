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

        uint _compRate = 0;
        for (uint i = 0; i < _allMarkets.length; i++) {
            address cToken = _allMarkets[i];
            Market storage market = markets[cToken];
            if (market.isComped == false) {
                _addCompMarketInternal(cToken);
            }
            compSpeeds[cToken] = _compSpeeds[i];
            _compRate = add_(_compRate, _compSpeeds[i]);
        }
        _setCompRate(_compRate);
    }


    function refreshCompSpeeds() public {
        require(!qsConfig.compSpeedGuardianPaused(), "compSpeed is paused");
        require(msg.sender == tx.origin, "only externally owned accounts may refresh speeds");

        refreshCompSpeedsInternal();
    }

    function refreshCompSpeedsInternal() internal {
        if (qsConfig.compSpeedGuardianPaused()) {
            return;
        } else {
            super.refreshCompSpeedsInternal();
        }
    }

    function getCompAddress() public view returns (address) {
        return qsConfig.compToken();
    }
    
    function calculateSeizeTokenAllocation(uint _seizeTokenAmount) public view returns(uint liquidatorAmount, uint safetyVaultAmount) {
        return qsConfig.calculateSeizeTokenAllocation(_seizeTokenAmount, liquidationIncentiveMantissa);
    }
    
    function transferComp(address user, uint userAccrued, uint threshold) internal returns (uint) {
        address compAddress = getCompAddress();
        if (userAccrued >= threshold && userAccrued > 0 && compAddress != address(0x0)) {
            EIP20Interface comp = EIP20Interface(compAddress);
            uint compRemaining = comp.balanceOf(address(this));
            if (userAccrued <= compRemaining) {
                comp.transfer(user, userAccrued);
                return 0;
            }
        }
        return userAccrued;
    }
}
pragma solidity ^0.5.16;

import "./compound/Comptroller.sol";

contract Qstroller is Comptroller {
    bool public compSpeedGuardianPaused;
    address public compToken;

    /**
     * @notice Sets new governance token distribution speed
     * @dev Admin function to set new token distribution speed
     */
    function _setCompSpeeds(address[] memory _allMarkets, uint[] memory _compSpeeds) public {
        // Check caller is admin
        require(msg.sender == admin, "Only admin can update token distribution");
        require(_allMarkets.length == _compSpeeds.length, "Incomplete parameter");
        require(allMarkets.length == _allMarkets.length, "Must update token distribution within one transaction");
        _setCompSpeedGuardianPaused(true);

        for (uint i = 0; i < _allMarkets.length; i++) {
            compSpeeds[_allMarkets[i]] = _compSpeeds[i];
        }
    }

    function _setCompSpeedGuardianPaused(bool state) public returns (bool) {
        require(msg.sender == pauseGuardian || msg.sender == admin, "only pause guardian and admin can pause");
        require(msg.sender == admin || state == true, "only admin can unpause");

        compSpeedGuardianPaused = state;
        emit ActionPaused("CompSpeed", state);
        return state;
    }

    function refreshCompSpeeds() public {
        require(!compSpeedGuardianPaused, "compSpeed is paused");
        require(msg.sender == tx.origin, "only externally owned accounts may refresh speeds");

        refreshCompSpeedsInternal();
    }

    function _setCompToken(address _compToken) public {
        require(msg.sender == admin, "only admin can set comp token");

        compToken = _compToken;
    }

    function getCompAddress() public view returns (address) {
        return compToken;
    }
}
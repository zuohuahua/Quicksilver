pragma solidity ^0.5.16;

import "./compound/Unitroller.sol";
import "./compound/Exponential.sol";
import "./Ownable.sol";

contract QsConfig is Ownable, Exponential {
    bool public compSpeedGuardianPaused = true;
    address public compToken;
    uint public safetyVaultRatio;
    address public safetyVault;

    uint public compRatio = 0.5e18;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public blacklist;

    event NewCompToken(address oldCompToken, address newCompToken);
    event NewSafetyVault(address oldSafetyVault, address newSafetyVault);
    event NewSafetyVaultRatio(uint oldSafetyVaultRatio, uint newSafetyVault);

    event NewCompRatio(uint oldCompRatio, uint newCompRatio);
    event WhitelistChange(address user, bool enabled);
    event BlacklistChange(address user, bool enabled);

    constructor(QsConfig previousQsConfig) public {
        if (address(previousQsConfig) == address(0x0)) return;

        compToken = previousQsConfig.compToken();
        safetyVaultRatio = previousQsConfig.safetyVaultRatio();
        safetyVault = previousQsConfig.safetyVault();
    }

    function _setCompToken(address _compToken) public onlyOwner {
        address oldCompToken = compToken;
        compToken = _compToken;
        emit NewCompToken(oldCompToken, compToken);
    }

    function _setSafetyVault(address _safetyVault) public onlyOwner {
        address oldSafetyVault = safetyVault;
        safetyVault = _safetyVault;
        emit NewSafetyVault(oldSafetyVault, safetyVault);
    }

    function _setSafetyVaultRatio(uint _safetyVaultRatio) public onlyOwner {
        uint oldSafetyVaultRatio = safetyVaultRatio;
        safetyVaultRatio = _safetyVaultRatio;
        emit NewSafetyVaultRatio(oldSafetyVaultRatio, safetyVaultRatio);
    }
    
    function _setCompSpeedGuardianPaused(bool state) public onlyOwner returns (bool) {
        compSpeedGuardianPaused = state;
        return state;
    }
    
    function calculateSeizeTokenAllocation(uint _seizeTokenAmount, uint liquidationIncentiveMantissa) public view returns(uint liquidatorAmount, uint safetyVaultAmount) {
        Exp memory vaultRatio = Exp({mantissa:safetyVaultRatio});
        (,Exp memory tmp) = mulScalar(vaultRatio, _seizeTokenAmount);
        safetyVaultAmount = div_(tmp, liquidationIncentiveMantissa).mantissa;
        liquidatorAmount = sub_(_seizeTokenAmount, safetyVaultAmount);
    }

    function getCompAllocation(address user, uint userAccrued) public view returns(uint userAmount, uint governanceAmount) {
        if (!isContract(user) || whitelist[user]) {
            return (userAccrued, 0);
        }

        Exp memory compRatioExp = Exp({mantissa:compRatio});
        (, userAmount) = mulScalarTruncate(compRatioExp, userAccrued);
        governanceAmount = sub_(userAccrued, userAmount);
    }

    function _setCompRatio(uint _compRatio) public onlyOwner {
        require(_compRatio < 1e18, "compRatio should be less then 100%");
        uint oldCompRatio = compRatio;
        compRatio = _compRatio;

        emit NewCompRatio(oldCompRatio, compRatio);
    }

    function isBlocked(address user) public view returns (bool) {
        return blacklist[user];
    }

    function _addToWhitelist(address _member) public onlyOwner {
        require(_member != address(0x0), "Zero address is not allowed");
        whitelist[_member] = true;

        emit WhitelistChange(_member, true);
    }

    function _removeFromWhitelist(address _member) public onlyOwner {
        require(_member != address(0x0), "Zero address is not allowed");
        whitelist[_member] = false;

        emit WhitelistChange(_member, false);
    }

    function _addToBlacklist(address _member) public onlyOwner {
        require(_member != address(0x0), "Zero address is not allowed");
        blacklist[_member] = true;

        emit BlacklistChange(_member, true);
    }

    function _removeFromBlacklist(address _member) public onlyOwner {
        require(_member != address(0x0), "Zero address is not allowed");
        blacklist[_member] = false;

        emit BlacklistChange(_member, false);
    }

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}
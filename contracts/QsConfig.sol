pragma solidity ^0.5.16;

import "./compound/Unitroller.sol";
import "./compound/Exponential.sol";
import "./Ownable.sol";

contract QsConfig is Ownable, Exponential {
    bool public compSpeedGuardianPaused = true;
    address public compToken;
    uint public safetyVaultRatio;
    address public safetyVault;

    event NewCompToken(address oldCompToken, address newCompToken);
    event NewSafetyVault(address oldSafetyVault, address newSafetyVault);
    event NewSafetyVaultRatio(uint oldSafetyVaultRatio, uint newSafetyVault);

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
}
pragma solidity ^0.5.16;

import "./compound/Unitroller.sol";
import "./compound/Exponential.sol";
import "./Ownable.sol";

contract QsConfig is Ownable, Exponential {
    bool public compSpeedGuardianPaused = true;
    address public compToken;
    uint public safetyVaultRatio;
    address public safetyVault;

    struct MarketCap {
        /**
       *  The borrow capacity of the asset, will be checked in borrowAllowed()
       *  0 means there is no limit on the capacity
       */
        uint borrowCap;

        /**
         *  The supply capacity of the asset, will be checked in mintAllowed()
         *  0 means there is no limit on the capacity
         */
        uint supplyCap;

        /**
         *  The flash loan capacity of the asset, will be checked in flashLoanAllowed()
         *  0 means there is no limit on the capacity
         */
        uint flashLoanCap;
    }

    uint public compRatio = 0.5e18;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public blacklist;
    mapping(address => MarketCap) marketsCap;
    // creditLimits allowed specific protocols to borrow and repay without collateral
    mapping(address => uint) public creditLimits;
    uint public flashLoanFeeRatio = 0.0001e18;

    event NewCompToken(address oldCompToken, address newCompToken);
    event NewSafetyVault(address oldSafetyVault, address newSafetyVault);
    event NewSafetyVaultRatio(uint oldSafetyVaultRatio, uint newSafetyVault);

    event NewCompRatio(uint oldCompRatio, uint newCompRatio);
    event WhitelistChange(address user, bool enabled);
    event BlacklistChange(address user, bool enabled);
    /// @notice Emitted when protocol's credit limit has changed
    event CreditLimitChanged(address protocol, uint creditLimit);
    event FlashLoanFeeRatioChanged(uint oldFeeRatio, uint newFeeRatio);

    /// @notice Emitted when borrow cap for a cToken is changed
    event NewBorrowCap(address indexed cToken, uint newBorrowCap);

    /// @notice Emitted when supply cap for a cToken is changed
    event NewSupplyCap(address indexed cToken, uint newSupplyCap);

    /// @notice Emitted when flash loan for a cToken is changed
    event NewFlashLoanCap(address indexed cToken, uint newFlashLoanCap);

    constructor(QsConfig previousQsConfig) public {
        if (address(previousQsConfig) == address(0x0)) return;

        compToken = previousQsConfig.compToken();
        safetyVaultRatio = previousQsConfig.safetyVaultRatio();
        safetyVault = previousQsConfig.safetyVault();
    }

        /**
          * @notice Set the given borrow caps for the given cToken markets. Borrowing that brings total borrows to or above borrow cap will revert.
          * @dev Admin function to set the borrow caps. A borrow cap of 0 corresponds to unlimited borrowing.
          * @param cTokens The addresses of the markets (tokens) to change the borrow caps for
          * @param newBorrowCaps The new borrow cap values in underlying to be set. A value of 0 corresponds to unlimited borrowing.
          */
        function _setMarketBorrowCaps(address[] calldata cTokens, uint[] calldata newBorrowCaps) external onlyOwner {
            uint numMarkets = cTokens.length;
            uint numBorrowCaps = newBorrowCaps.length;

            require(numMarkets != 0 && numMarkets == numBorrowCaps, "invalid input");

            for(uint i = 0; i < numMarkets; i++) {
                marketsCap[cTokens[i]].borrowCap = newBorrowCaps[i];
                emit NewBorrowCap(cTokens[i], newBorrowCaps[i]);
            }
        }

        /**
         * @notice Set the given flash loan caps for the given cToken markets. Borrowing that brings total flash cap to or above flash loan cap will revert.
         * @dev Admin function to set the flash loan caps. A flash loan cap of 0 corresponds to unlimited flash loan.
         * @param cTokens The addresses of the markets (tokens) to change the flash loan caps for
         * @param newFlashLoanCaps The new flash loan cap values in underlying to be set. A value of 0 corresponds to unlimited flash loan.
         */
        function _setMarketFlashLoanCaps(address[] calldata cTokens, uint[] calldata newFlashLoanCaps) external onlyOwner {
            uint numMarkets = cTokens.length;
            uint numFlashLoanCaps = newFlashLoanCaps.length;

            require(numMarkets != 0 && numMarkets == numFlashLoanCaps, "invalid input");

            for(uint i = 0; i < numMarkets; i++) {
                marketsCap[cTokens[i]].flashLoanCap = newFlashLoanCaps[i];
                emit NewFlashLoanCap(cTokens[i], newFlashLoanCaps[i]);
            }
        }

        /**
         * @notice Set the given supply caps for the given cToken markets. Supplying that brings total supply to or above supply cap will revert.
         * @dev Admin function to set the supply caps. A supply cap of 0 corresponds to unlimited supplying.
         * @param cTokens The addresses of the markets (tokens) to change the supply caps for
         * @param newSupplyCaps The new supply cap values in underlying to be set. A value of 0 corresponds to unlimited supplying.
         */
        function _setMarketSupplyCaps(address[] calldata cTokens, uint[] calldata newSupplyCaps) external onlyOwner {
            uint numMarkets = cTokens.length;
            uint numSupplyCaps = newSupplyCaps.length;

            require(numMarkets != 0 && numMarkets == numSupplyCaps, "invalid input");

            for(uint i = 0; i < numMarkets; i++) {
                marketsCap[cTokens[i]].supplyCap = newSupplyCaps[i];
                emit NewSupplyCap(cTokens[i], newSupplyCaps[i]);
            }
        }
    /**
     * @notice Sets whitelisted protocol's credit limit
     * @param protocol The address of the protocol
     * @param creditLimit The credit limit
     */
    function _setCreditLimit(address protocol, uint creditLimit) public {
        require(msg.sender == owner(), "only owner can set protocol credit limit");

        creditLimits[protocol] = creditLimit;
        emit CreditLimitChanged(protocol, creditLimit);
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

    function getCreditLimit(address protocol) external view returns (uint) {
        return creditLimits[protocol];
    }

    function getBorrowCap(address cToken) external view returns (uint) {
        return marketsCap[cToken].borrowCap;
    }

    function getSupplyCap(address cToken) external view returns (uint) {
        return marketsCap[cToken].supplyCap;
    }

    function getFlashLoanCap(address cToken) external view returns (uint) {
        return marketsCap[cToken].flashLoanCap;
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

    function getFlashFee(address borrower, address token, uint256 amount) external view returns (uint flashFee) {
        if (whitelist[borrower]) {
            return 0;
        }
        Exp memory flashLoanFeeRatioExp = Exp({mantissa:flashLoanFeeRatio});
        (, flashFee) = mulScalarTruncate(flashLoanFeeRatioExp, amount);

        token;
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

    function _setFlashLoanFeeRatio(uint _feeRatio) public onlyOwner {
        require(_feeRatio != flashLoanFeeRatio, "Same fee ratio already set");
        require(_feeRatio < 1e18, "Invalid fee ratio");

        uint oldFeeRatio = flashLoanFeeRatio;
        flashLoanFeeRatio = _feeRatio;

        emit FlashLoanFeeRatioChanged(oldFeeRatio, flashLoanFeeRatio);
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
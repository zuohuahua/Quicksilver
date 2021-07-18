pragma solidity ^0.5.16;

import "./compound/Comptroller.sol";
import "./compound/EIP20Interface.sol";
import "./QsConfig.sol";

contract Qstroller is Comptroller {
    QsConfig public qsConfig;

    function _setQsConfig(QsConfig _qsConfig) public {
        require(msg.sender == admin);

        qsConfig = _qsConfig;
    }

    /**
     * @notice Sets new governance token distribution speed
     * @dev Admin function to set new token distribution speed
     */
    function _setCompSpeeds(address[] memory _allMarkets, uint[] memory _compSpeeds) public {
        // Check caller is admin
        require(msg.sender == admin);
        
        require(_allMarkets.length == _compSpeeds.length);

        uint _compRate = 0;
        for (uint i = 0; i < _allMarkets.length; i++) {
            address cToken = _allMarkets[i];
            Market storage market = markets[cToken];
            if (market.isComped == false) {
                _addCompMarketInternal(cToken);
            }
            compSpeeds[cToken] = _compSpeeds[i];
            uint supplySpeed = _compSpeeds[i] >> 128;
            uint borrowSpeed = uint128(_compSpeeds[i]);
            uint compSpeed = add_(supplySpeed, borrowSpeed);
            _compRate = add_(_compRate, compSpeed);
        }
        compRate = _compRate;
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
                (uint userAmount, uint governanceAmount) = qsConfig.getCompAllocation(user, userAccrued);
                if (userAmount > 0) comp.transfer(user, userAmount);
                if (governanceAmount > 0) comp.transfer(qsConfig.safetyVault(), governanceAmount);
                return 0;
            }
        }
        return userAccrued;
    }

    /**
  * @notice Checks if the account should be allowed to borrow the underlying asset of the given market
  * @param cToken The market to verify the borrow against
  * @param borrower The account which would borrow the asset
  * @param borrowAmount The amount of underlying the account would borrow
  * @return 0 if the borrow is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
  */
    function borrowAllowed(address cToken, address borrower, uint borrowAmount) external returns (uint) {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!borrowGuardianPaused[cToken], "borrow is paused");

        if (!markets[cToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        if (!markets[cToken].accountMembership[borrower]) {
            // only cTokens may call borrowAllowed if borrower not in market
            require(msg.sender == cToken, "sender must be cToken");

            // attempt to add borrower to the market
            Error err = addToMarketInternal(CToken(msg.sender), borrower);
            if (err != Error.NO_ERROR) {
                return uint(err);
            }

            // it should be impossible to break the important invariant
            assert(markets[cToken].accountMembership[borrower]);
        }

        if (oracle.getUnderlyingPrice(CToken(cToken)) == 0) {
            return uint(Error.PRICE_ERROR);
        }

        uint borrowCap = markets[cToken].borrowCap;
        if (qsConfig.getBorrowCap(borrowCap) != borrowCap) {
            borrowCap = qsConfig.getBorrowCap(borrowCap);
        }
        // Borrow cap of 0 corresponds to unlimited borrowing
        if (borrowCap != 0) {
            uint totalBorrows = CToken(cToken).totalBorrows();
            (MathError mathErr, uint nextTotalBorrows) = addUInt(totalBorrows, borrowAmount);
            require(mathErr == MathError.NO_ERROR, "total borrows overflow");
            require(nextTotalBorrows < borrowCap, "market borrow cap reached");
        }

        (Error err, , uint shortfall) = getHypotheticalAccountLiquidityInternal(borrower, CToken(cToken), 0, borrowAmount);
        if (err != Error.NO_ERROR) {
            return uint(err);
        }
        if (shortfall > 0) {
            return uint(Error.INSUFFICIENT_LIQUIDITY);
        }

        // Keep the flywheel moving
        Exp memory borrowIndex = Exp({mantissa: CToken(cToken).borrowIndex()});
        updateCompBorrowIndex(cToken, borrowIndex);
        distributeBorrowerComp(cToken, borrower, borrowIndex, false);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account should be allowed to mint tokens in the given market
     * @param cToken The market to verify the mint against
     * @param minter The account which would get the minted tokens
     * @param mintAmount The amount of underlying being supplied to the market in exchange for tokens
     * @return 0 if the mint is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function mintAllowed(address cToken, address minter, uint mintAmount) external returns (uint) {
        require(!qsConfig.isBlocked(minter));
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!mintGuardianPaused[cToken]);

        // Shh - currently unused
        minter;
        mintAmount;

        if (!markets[cToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        uint supplyCap = markets[cToken].supplyCap;
        if (qsConfig.getSupplyCap(supplyCap) != supplyCap) {
            supplyCap = qsConfig.getSupplyCap(supplyCap);
        }
        // Supply cap of 0 corresponds to unlimited borrowing
        if (supplyCap != 0) {
            Exp memory exchangeRate = Exp({mantissa: CTokenInterface(cToken).exchangeRateCurrent()});
            (MathError mErr, uint totalSupplyUnderlying) = mulScalarTruncate(exchangeRate, EIP20Interface(cToken).totalSupply());
            require(mErr == MathError.NO_ERROR, "totalSupplyUnderlying could not be calculated");
            (MathError mathErr, uint nextTotalSupplyUnderlying) = addUInt(totalSupplyUnderlying, mintAmount);
            require(mathErr == MathError.NO_ERROR, "total supplies overflow");
            require(nextTotalSupplyUnderlying <= supplyCap, "market supply cap reached");
        }

        // Keep the flywheel moving
        updateCompSupplyIndex(cToken);
        distributeSupplierComp(cToken, minter, false);
        return uint(Error.NO_ERROR);
    }

    /**
  * @notice Accrue COMP to the market by updating the supply index
  * @param cToken The market whose supply index to update
  */
    function updateCompSupplyIndex(address cToken) internal {
        CompMarketState storage supplyState = compSupplyState[cToken];
        uint supplySpeed = compSpeeds[cToken];
        // use first 128 bit as supplySpeed
        supplySpeed = supplySpeed >> 128 == 0 ? supplySpeed : supplySpeed >> 128;
        uint blockNumber = getBlockNumber();
        uint deltaBlocks = sub_(blockNumber, uint(supplyState.block));
        if (deltaBlocks > 0 && supplySpeed > 0) {
            uint supplyTokens = CToken(cToken).totalSupply();
            uint compAccrued = mul_(deltaBlocks, supplySpeed);
            Double memory ratio = supplyTokens > 0 ? fraction(compAccrued, supplyTokens) : Double({mantissa: 0});
            Double memory index = add_(Double({mantissa: supplyState.index}), ratio);
            compSupplyState[cToken] = CompMarketState({
            index: safe224(index.mantissa, "index > 224bits"),
            block: safe32(blockNumber, "blockNumber > 32bits")
            });
        } else if (deltaBlocks > 0 && supplyState.index > 0) {
            supplyState.block = safe32(blockNumber, "blockNumber > 32bits");
        }
    }

    /**
     * @notice Accrue COMP to the market by updating the borrow index
     * @param cToken The market whose borrow index to update
     */
    function updateCompBorrowIndex(address cToken, Exp memory marketBorrowIndex) internal {
        CompMarketState storage borrowState = compBorrowState[cToken];
        // use last 128 bit as borrowSpeed
        uint borrowSpeed = uint128(compSpeeds[cToken]);
        uint blockNumber = getBlockNumber();
        uint deltaBlocks = sub_(blockNumber, uint(borrowState.block));
        if (deltaBlocks > 0 && borrowSpeed > 0) {
            uint borrowAmount = div_(CToken(cToken).totalBorrows(), marketBorrowIndex);
            uint compAccrued = mul_(deltaBlocks, borrowSpeed);
            Double memory ratio = borrowAmount > 0 ? fraction(compAccrued, borrowAmount) : Double({mantissa: 0});
            Double memory index = add_(Double({mantissa: borrowState.index}), ratio);
            compBorrowState[cToken] = CompMarketState({
            index: safe224(index.mantissa, "index > 224bits"),
            block: safe32(blockNumber, "blockNumber > 32bits")
            });
        } else if (deltaBlocks > 0 && borrowState.index > 0) {
            borrowState.block = safe32(blockNumber, "blockNumber > 32bits");
        }
    }
}
pragma solidity ^0.5.16;

import "./compound/Comptroller.sol";
import "./compound/EIP20Interface.sol";
import "./QsConfig.sol";

contract Qstroller is Comptroller {
    /// @notice Emitted when an admin delists a market
    event MarketDelisted(CToken cToken);

    QsConfig public qsConfig;

    /**
     * @notice Remove the market from the markets mapping
     * @param cToken The address of the market (token) to delist
     */
    function _delistMarket(CToken cToken) external {
        require(msg.sender == admin, "only admin may delist market");

        require(markets[address(cToken)].isListed, "market not listed");
        require(cToken.totalSupply() == 0, "market not empty");

        cToken.isCToken(); // Sanity check to make sure its really a CToken

        delete markets[address(cToken)];

        for (uint i = 0; i < allMarkets.length; i++) {
            if (allMarkets[i] == cToken) {
                allMarkets[i] = allMarkets[allMarkets.length - 1];
                delete allMarkets[allMarkets.length - 1];
                allMarkets.length--;
                break;
            }
        }

        emit MarketDelisted(cToken);
    }

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

    /**
 * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
 * @param cTokenModify The market to hypothetically redeem/borrow in
 * @param account The account to determine liquidity for
 * @param redeemTokens The number of tokens to hypothetically redeem
 * @param borrowAmount The amount of underlying to hypothetically borrow
 * @dev Note that we calculate the exchangeRateStored for each collateral cToken using stored data,
 *  without calculating accumulated interest.
 * @return (possible error code,
            hypothetical account liquidity in excess of collateral requirements,
 *          hypothetical account shortfall below collateral requirements)
 */
    function getHypotheticalAccountLiquidityInternal(
        address account,
        CToken cTokenModify,
        uint redeemTokens,
        uint borrowAmount) internal view returns (Error, uint, uint) {

        // If credit limit is set to MAX, no need to check account liquidity.
        if (qsConfig.getCreditLimit(account) == uint(-1)) {
            return (Error.NO_ERROR, uint(-1), 0);
        }

        AccountLiquidityLocalVars memory vars; // Holds all our calculation results
        uint oErr;
        MathError mErr;

        // For each asset the account is in
        CToken[] memory assets = accountAssets[account];
        for (uint i = 0; i < assets.length; i++) {
            CToken asset = assets[i];

            // Read the balances and exchange rate from the cToken
            (oErr, vars.cTokenBalance, vars.borrowBalance, vars.exchangeRateMantissa) = asset.getAccountSnapshot(account);
            if (oErr != 0) { // semi-opaque error code, we assume NO_ERROR == 0 is invariant between upgrades
                return (Error.SNAPSHOT_ERROR, 0, 0);
            }
            vars.collateralFactor = Exp({mantissa: markets[address(asset)].collateralFactorMantissa});
            vars.borrowFactorMantissa = Exp({mantissa: markets[address(asset)].borrowFactorMantissa});
            vars.exchangeRate = Exp({mantissa: vars.exchangeRateMantissa});

            // Get the normalized price of the asset
            vars.oraclePriceMantissa = oracle.getUnderlyingPrice(asset);
            if (vars.oraclePriceMantissa == 0) {
                return (Error.PRICE_ERROR, 0, 0);
            }
            vars.oraclePrice = Exp({mantissa: vars.oraclePriceMantissa});

            // Pre-compute a conversion factor from tokens -> ether (normalized price value)
            (mErr, vars.tokensToDenom) = mulExp3(vars.collateralFactor, vars.exchangeRate, vars.oraclePrice);
            if (mErr != MathError.NO_ERROR) {
                return (Error.MATH_ERROR, 0, 0);
            }

            // sumCollateral += tokensToDenom * cTokenBalance
            (mErr, vars.sumCollateral) = mulScalarTruncateAddUInt(vars.tokensToDenom, vars.cTokenBalance, vars.sumCollateral);
            if (mErr != MathError.NO_ERROR) {
                return (Error.MATH_ERROR, 0, 0);
            }

            // borrowValue = borrowBalance / borrowFactor
            uint borrowValue = div_(vars.borrowBalance, vars.borrowFactorMantissa);
            // sumBorrowPlusEffects += oraclePrice * borrowValue
            (mErr, vars.sumBorrowPlusEffects) = mulScalarTruncateAddUInt(vars.oraclePrice, borrowValue, vars.sumBorrowPlusEffects);
            if (mErr != MathError.NO_ERROR) {
                return (Error.MATH_ERROR, 0, 0);
            }

            // Calculate effects of interacting with cTokenModify
            if (asset == cTokenModify) {
                // redeem effect
                // sumBorrowPlusEffects += tokensToDenom * redeemTokens
                (mErr, vars.sumBorrowPlusEffects) = mulScalarTruncateAddUInt(vars.tokensToDenom, redeemTokens, vars.sumBorrowPlusEffects);
                if (mErr != MathError.NO_ERROR) {
                    return (Error.MATH_ERROR, 0, 0);
                }

                // borrow effect
                // borrowValue = borrowAmount / borrowFactor
                borrowValue = div_(borrowAmount, vars.borrowFactorMantissa);
                // sumBorrowPlusEffects += oraclePrice * borrowValue
                (mErr, vars.sumBorrowPlusEffects) = mulScalarTruncateAddUInt(vars.oraclePrice, borrowValue, vars.sumBorrowPlusEffects);
                if (mErr != MathError.NO_ERROR) {
                    return (Error.MATH_ERROR, 0, 0);
                }
            }
        }

        // If credit limit is set, no need to consider collateral.
        if (qsConfig.getCreditLimit(account) > 0) {
            vars.sumCollateral = qsConfig.getCreditLimit(account);
        }

        // These are safe, as the underflow condition is checked first
        if (vars.sumCollateral > vars.sumBorrowPlusEffects) {
            return (Error.NO_ERROR, vars.sumCollateral - vars.sumBorrowPlusEffects, 0);
        } else {
            return (Error.NO_ERROR, 0, vars.sumBorrowPlusEffects - vars.sumCollateral);
        }
    }

    /**
     * @notice Checks if the liquidation should be allowed to occur
     * @param cTokenBorrowed Asset which was borrowed by the borrower
     * @param cTokenCollateral Asset which was used as collateral and will be seized
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param repayAmount The amount of underlying being repaid
     */
    function liquidateBorrowAllowed(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint repayAmount) public returns (uint) {
        require(qsConfig.getCreditLimit(borrower) == 0 , "cannot liquidate credit account");

        return super.liquidateBorrowAllowed(cTokenBorrowed, cTokenCollateral, liquidator, borrower, repayAmount);
    }

    function seizeAllowed(
        address cTokenCollateral,
        address cTokenBorrowed,
        address liquidator,
        address borrower,
        uint seizeTokens) public returns (uint) {
        require(qsConfig.getCreditLimit(borrower) == 0 , "cannot sieze from credit account");

        return super.seizeAllowed(cTokenCollateral, cTokenBorrowed, liquidator, borrower, seizeTokens);
    }


}
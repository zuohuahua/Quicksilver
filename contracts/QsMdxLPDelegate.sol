pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./compound/CErc20.sol";
import "./compound/EIP20Interface.sol";

// Ref: https://etherscan.io/address/0xc2edad668740f1aa35e4d8f227fb8e17dca888cd#code
interface HecoPool {
    struct PoolInfo {
        address lpToken;
    }

    function deposit(uint256, uint256) external;
    function withdraw(uint256, uint256) external;
    function mdx() view external returns (address);
    function poolInfo(uint256) view external returns (PoolInfo memory);
    function pending(uint256, address) external view returns (uint256);
}


/**
 * @title Mdex LP Contract
 * @notice CToken which wraps Mdex's LP token
 */
contract QsMdxLPDelegate is CErc20, CDelegateInterface {
    /**
     * @notice HecoPool address
     */
    address public hecoPool;

    /**
     * @notice MDX token address
     */
    address public mdx;

    /**
     * @notice Pool ID of this LP in HecoPool
     */
    uint public pid;

    /**
     * @notice cMdx address
     */
    address public cMdx;

    /**
     * @notice Container for rewards state
     * @member balance The balance of cMdx
     * @member index The last updated index
     */
    struct RewardState {
        uint balance;
        uint index;
    }

    /**
     * @notice The state of LP supply
     */
    RewardState public lpSupplyState;

    /**
     * @notice The index of every LP supplier
     */
    mapping(address => uint) public lpSupplierIndex;

    /**
     * @notice The cMdx amount of every user
     */
    mapping(address => uint) public cTokenUserAccrued;

    /**
     * @notice Construct an empty delegate
     */
    constructor() public {}

    /**
     * @notice Called by the delegator on a delegate to forfeit its responsibility
     */
    function _resignImplementation() public {
        // Shh -- we don't ever want this hook to be marked pure
        if (false) {
            implementation = address(0);
        }

        require(msg.sender == admin, "only admin");
    }

    /**
     * @notice Delegate interface to become the implementation
     * @param data The encoded arguments for becoming
     */
    function _becomeImplementation(bytes memory data) public {
        require(msg.sender == admin, "only admin");

        (address hecoPoolAddress_, address cMdxAddress_, uint pid_) = abi.decode(data, (address, address, uint));
        hecoPool = hecoPoolAddress_;
        mdx = HecoPool(hecoPool).mdx();
        cMdx = cMdxAddress_;

        HecoPool.PoolInfo memory poolInfo = HecoPool(hecoPool).poolInfo(pid_);
        require(poolInfo.lpToken == underlying, "mismatch underlying");
        pid = pid_;

        // Approve moving our LP into the heco pool contract.
        EIP20Interface(underlying).approve(hecoPoolAddress_, uint(-1));

        // Approve moving mdx rewards into the cmdx contract.
        EIP20Interface(mdx).approve(cMdxAddress_, uint(-1));
    }

    /**
     * @notice Manually claim rewards by user
     * @return The amount of cmdx rewards user claims
     */
    function claim(address account) public returns (uint) {
        claimAndStakeMdx();

        updateLPSupplyIndex();
        updateSupplierIndex(account);

        // Get user's cmdx accrued.
        uint cTokenBalance = cTokenUserAccrued[account];
        if (cTokenBalance > 0) {
            lpSupplyState.balance = sub_(lpSupplyState.balance, cTokenBalance);

            EIP20Interface(cMdx).transfer(account, cTokenBalance);

            // Clear user's cmdx accrued.
            cTokenUserAccrued[account] = 0;

            return cTokenBalance;
        }
        return 0;
    }

    /*** CToken Overrides ***/

    /**
     * @notice Transfer `tokens` tokens from `src` to `dst` by `spender`
     * @param spender The address of the account performing the transfer
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param tokens The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferTokens(address spender, address src, address dst, uint tokens) internal returns (uint) {
        claimAndStakeMdx();

        updateLPSupplyIndex();
        updateSupplierIndex(src);
        updateSupplierIndex(dst);

        return super.transferTokens(spender, src, dst, tokens);
    }

    /*** Safe Token ***/

    /**
     * @notice Transfer the underlying to this contract and sweep into master chef
     * @param from Address to transfer funds from
     * @param amount Amount of underlying to transfer
     * @param isNative The amount is in native or not
     * @return The actual amount that is transferred
     */
    function doTransferIn(address from, uint amount, bool isNative) internal returns (uint) {
        isNative; // unused

        // Perform the EIP-20 transfer in
        EIP20Interface token = EIP20Interface(underlying);
        require(token.transferFrom(from, address(this), amount), "unexpected EIP-20 transfer in return");

        // Deposit to HecoPool.
        HecoPool(hecoPool).deposit(pid, amount);

        if (mdxBalance() > 0) {
            // Send mdx rewards to cMdx.
            CErc20(cMdx).mint(mdxBalance());
        }

        updateLPSupplyIndex();
        updateSupplierIndex(from);

        return amount;
    }

    /**
     * @notice Transfer the underlying from this contract, after sweeping out of master chef
     * @param to Address to transfer funds to
     * @param amount Amount of underlying to transfer
     * @param isNative The amount is in native or not
     */
    function doTransferOut(address payable to, uint amount, bool isNative) internal {
        isNative; // unused

        // Withdraw the underlying tokens from HecoPool.
        HecoPool(hecoPool).withdraw(pid, amount);

        if (mdxBalance() > 0) {
            // Send mdx rewards to cMdx.
            CErc20(cMdx).mint(mdxBalance());
        }

        updateLPSupplyIndex();
        updateSupplierIndex(to);

        EIP20Interface token = EIP20Interface(underlying);
        require(token.transfer(to, amount), "unexpected EIP-20 transfer out return");
    }

    /*** Internal functions ***/

    function claimAndStakeMdx() internal {
        // Deposit 0 LP into HecoPool to claim mdx rewards.
        HecoPool(hecoPool).deposit(pid, 0);

        if (mdxBalance() > 0) {
            // Send mdx rewards to mdx pool.
            CErc20(cMdx).mint(mdxBalance());
        }
    }

    function updateLPSupplyIndex() internal {
        uint cTokenBalance = cTokenBalance();
        uint cTokenAccrued = sub_(cTokenBalance, lpSupplyState.balance);
        uint supplyTokens = CToken(address(this)).totalSupply();
        Double memory ratio = supplyTokens > 0 ? fraction(cTokenAccrued, supplyTokens) : Double({mantissa: 0});
        Double memory index = add_(Double({mantissa: lpSupplyState.index}), ratio);

        // Update lpSupplyState.
        lpSupplyState.index = index.mantissa;
        lpSupplyState.balance = cTokenBalance;
    }

    function updateSupplierIndex(address supplier) internal {
        Double memory supplyIndex = Double({mantissa: lpSupplyState.index});
        Double memory supplierIndex = Double({mantissa: lpSupplierIndex[supplier]});
        Double memory deltaIndex = sub_(supplyIndex, supplierIndex);
        if (deltaIndex.mantissa > 0) {
            uint supplierTokens = CToken(address(this)).balanceOf(supplier);
            uint supplierDelta = mul_(supplierTokens, deltaIndex);
            cTokenUserAccrued[supplier] = add_(cTokenUserAccrued[supplier], supplierDelta);
            lpSupplierIndex[supplier] = supplyIndex.mantissa;
        }
    }

    function mdxBalance() internal view returns (uint) {
        return EIP20Interface(mdx).balanceOf(address(this));
    }

    function cTokenBalance() internal view returns (uint) {
        return EIP20Interface(cMdx).balanceOf(address(this));
    }
}

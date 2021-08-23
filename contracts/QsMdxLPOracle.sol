pragma solidity ^0.5.16;

import "./ChainlinkAggregatorV3Interface.sol";
import "./IUniswapV2Pair.sol";
import "./compound/SafeMath.sol";
import "./compound/EIP20Interface.sol";

contract QsMdxLPOracle is ChainlinkAggregatorV3Interface {
    using SafeMath for uint;
    using SafeMath for uint8;

    uint8 private decimals_;
    string private description_;
    address public pair;

    ChainlinkAggregatorV3Interface public token0Source;
    ChainlinkAggregatorV3Interface public token1Source;

    uint private half0Decimals;
    uint private half1Decimals;

    constructor(
        uint8 _decimals,
        string memory _description,
        address _token0ChanlinkSource,
        address _token1ChanlinkSource,
        address _pair) public {
        decimals_ = _decimals;
        description_ = _description;
        token0Source = ChainlinkAggregatorV3Interface(_token0ChanlinkSource);
        token1Source = ChainlinkAggregatorV3Interface(_token1ChanlinkSource);
        pair = _pair;

        half0Decimals = token0Source.decimals().div(2);
        half1Decimals = token1Source.decimals().div(2);
    }

    function decimals() external view returns (uint8) {
        return decimals_;
    }

    function description() external view returns (string memory) {
        return description_;
    }

    function version() external view returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId) public
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        _roundId;

        uint totalSupply = IUniswapV2Pair(pair).totalSupply();
        (uint r0, uint r1, ) = IUniswapV2Pair(pair).getReserves();
        uint sqrtK = sqrt(r0.mul(r1)).mul(10 ** uint(decimals_)).div(totalSupply);
        uint px0 = getTokenPrice(IUniswapV2Pair(pair).token0(), token0Source);
        uint px1 = getTokenPrice(IUniswapV2Pair(pair).token1(), token1Source);
        // fair token0 amt: sqrtK * sqrt(px1/px0)
        // fair token1 amt: sqrtK * sqrt(px0/px1)
        // fair lp price = 2 * sqrt(px0 * px1)
        // split into 2 sqrts multiplication to prevent uint overflow
        answer = int256(sqrtK.mul(2).mul(sqrt(px0)).div(10 ** uint(half0Decimals)).mul(sqrt(px1)).div(10 ** uint(half1Decimals)));
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        roundId = 0;
        answeredInRound = 0;
    }

    function latestRoundData()
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return getRoundData(0);
    }

    function getTokenPrice(address token, ChainlinkAggregatorV3Interface tokenSource) private view returns (uint) {
        uint tokenDecimals = uint(EIP20Interface(token).decimals());
        (,int256 answer,,,) = tokenSource.latestRoundData();
        return uint(answer).mul(1e18).div(10 ** tokenDecimals);
    }

    // implementation from https://github.com/Uniswap/uniswap-lib/commit/99f3f28770640ba1bb1ff460ac7c5292fb8291a0
    // original implementation: https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.sol#L687
    function sqrt(uint x) internal pure returns (uint) {
        if (x == 0) return 0;
        uint xx = x;
        uint r = 1;

        if (xx >= 0x100000000000000000000000000000000) {
            xx >>= 128;
            r <<= 64;
        }

        if (xx >= 0x10000000000000000) {
            xx >>= 64;
            r <<= 32;
        }
        if (xx >= 0x100000000) {
            xx >>= 32;
            r <<= 16;
        }
        if (xx >= 0x10000) {
            xx >>= 16;
            r <<= 8;
        }
        if (xx >= 0x100) {
            xx >>= 8;
            r <<= 4;
        }
        if (xx >= 0x10) {
            xx >>= 4;
            r <<= 2;
        }
        if (xx >= 0x8) {
            r <<= 1;
        }

        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; // Seven iterations should be enough
        uint r1 = x / r;
        return (r < r1 ? r : r1);
    }
}

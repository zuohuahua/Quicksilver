pragma solidity ^0.5.16;

import "./compound/SafeMath.sol";
import "./compound/PriceOracle.sol";
import "./compound/CErc20.sol";
import "./ChainlinkAggregatorV3Interface.sol";
import "./SToken.sol";

contract ChainlinkAdaptor is PriceOracle {
    using SafeMath for uint256;

    address public governance;

    mapping(address => ChainlinkAggregatorV3Interface) public assetsPriceSources;
    ChainlinkAggregatorV3Interface public nativeTokenPriceSource;

    PriceOracle public fallbackPriceOracle;

    event AssetPriceSourceUpdated(address indexed asset, address indexed source);

    modifier onlyGovernance {
        require(msg.sender == governance, "Governance required.");
        _;
    }

    constructor(address _nativeTokenPriceSource) public {
        governance = msg.sender;
        nativeTokenPriceSource = ChainlinkAggregatorV3Interface(_nativeTokenPriceSource);
    }

    function getUnderlyingPrice(CToken cToken) external view returns (uint) {
        if (SToken(address(cToken)).isNativeToken()) {
            return 1e18;
        }

        address asset = address(CErc20(address(cToken)).underlying());
        ChainlinkAggregatorV3Interface priceSource = assetsPriceSources[asset];

        if (address(priceSource) == address(0x0)) {
            return getUnderlyingPriceFromFallback(cToken);
        }

        uint256 assetPriceDecimals = assetsPriceSources[asset].decimals();
        uint256 assetDecimals = CToken(asset).decimals();
        uint256 assetPriceInUsd = getPrice(assetsPriceSources[asset]);

        uint256 nativeTokenPriceDecimals = nativeTokenPriceSource.decimals();
        uint256 nativeTokenPriceInUsd = getPrice(nativeTokenPriceSource);

        if (assetPriceInUsd == 0 || nativeTokenPriceInUsd == 0) {
            return getUnderlyingPriceFromFallback(cToken);
        }

        if (assetPriceDecimals == nativeTokenPriceDecimals) {
            return assetPriceInUsd.mul(10 ** 18).mul(10 ** 18).div(nativeTokenPriceInUsd.mul(10 ** assetDecimals));
        } else {
            return assetPriceInUsd.mul(10 ** 18).mul(10 ** nativeTokenPriceDecimals).mul(10 ** 18).div(nativeTokenPriceInUsd.mul(10 ** assetDecimals).mul(10 ** assetPriceDecimals));
        }
    }

    function getUnderlyingPriceFromFallback(CToken cToken) public view returns (uint) {
        if (address(fallbackPriceOracle) != address(0x0)) {
            return fallbackPriceOracle.getUnderlyingPrice(cToken);
        }
        return 0;
    }

    function getSourcePrice(address asset) view public returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        return assetsPriceSources[asset].latestRoundData();
    }

    function getPrice(ChainlinkAggregatorV3Interface priceSource) public view returns (uint256) {
        (,int256 answer,,,) = priceSource.latestRoundData();
        if (answer > 0) {
            return uint256(answer);
        } else {
            return 0;
        }
    }

    function setAssetSources(address[] calldata assets, address[] calldata sources) external onlyGovernance {
        _setAssetsSources(assets, sources);
    }

    function setFallbackPriceOracle(address _fallbackPriceOracle) external onlyGovernance {
        fallbackPriceOracle = PriceOracle(_fallbackPriceOracle);
    }

    function _setAssetsSources(address[] memory assets, address[] memory sources) internal {
        require(assets.length == sources.length, 'Inconsistent parameter length');
        for (uint256 i = 0; i < assets.length; i++) {
            assetsPriceSources[assets[i]] = ChainlinkAggregatorV3Interface(sources[i]);
            emit AssetPriceSourceUpdated(assets[i], sources[i]);
        }
    }
}
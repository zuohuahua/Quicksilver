pragma solidity ^0.4.0;

abstract contract IPriceCollector {
    function assetPrices(address asset) external view returns (uint);
}

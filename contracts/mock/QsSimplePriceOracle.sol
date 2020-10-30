pragma solidity ^0.5.16;

import "../compound/SimplePriceOracle.sol";

contract QsSimplePriceOracle is SimplePriceOracle {
    function getUnderlyingPrice(CToken cToken) public view returns (uint) {
        if (compareStrings(cToken.symbol(), "sETH") || compareStrings(cToken.symbol(), "sELA")) {
            return 1e18;
        } else {
            return prices[address(CErc20(address(cToken)).underlying())];
        }
    }
}
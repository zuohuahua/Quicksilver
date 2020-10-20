pragma solidity ^0.5.16;

import "../PriceOracle.sol";
import "../SafeMath.sol";

contract MockPriceOracle is PriceOracle {
    using SafeMath for uint256;

    function getUnderlyingPrice(CToken cToken) external view returns (uint) {
        if (compareStrings(cToken.symbol(), "sETH") || compareStrings(cToken.symbol(), "sELA")) {
            return 1e18;
        } else {
            // 10 ETH
            uint256 ethAmount = 10e18;
            // 4000 USDT
            uint256 tokenAmount = 4000 * 1e6;
            uint256 ethForToken = ethAmount.mul(1e18).div(tokenAmount);
            return ethForToken;
        }
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}

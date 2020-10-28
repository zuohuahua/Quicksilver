pragma solidity ^0.5.16;

import "./TetherToken.sol";

contract ETHToken is TetherToken(1000000000 ether, "ETH on Elastos", "ETH", 18) {
}
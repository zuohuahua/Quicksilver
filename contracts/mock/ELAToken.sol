pragma solidity ^0.5.16;

import "./TetherToken.sol";

contract ELAToken is TetherToken(1000000000 ether, "ELA on ETH", "ELA", 18) {
}
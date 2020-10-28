pragma solidity ^0.5.16;

import "./TetherToken.sol";

contract HFILToken is TetherToken(1000000000 ether, "Huobi Fil", "HFIL", 18) {
}
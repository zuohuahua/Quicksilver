pragma solidity ^0.5.16;

contract IPriceCollector {
    function setDirectPrice(address asset, uint price) public;
}

pragma solidity ^0.4.0;

abstract contract IPriceCollector {
    function setDirectPrice(address asset, uint price) public;
}

pragma solidity ^0.5.16;

import "./compound/PriceOracle.sol";
import "./compound/CErc20.sol";
import "./IPriceCollector.sol";
import "./SToken.sol";

contract QsPriceOracleV2 is PriceOracle, IPriceCollector {
    mapping(address => uint) prices;
    mapping(address => bool) public priceAdmin;

    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);
    event PriceAdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event PriceAdminAdded(address newAdmin);
    event PriceAdminRemoved(address newAdmin);

    modifier onlyAdmin {
        require(priceAdmin[msg.sender], "Price Admin required.");
        _;
    }

    constructor() public {
        priceAdmin[msg.sender] = true;
    }

    function getUnderlyingPrice(CToken cToken) public view returns (uint) {
        if (SToken(address(cToken)).isNativeToken()) {
            return 1e18;
        } else {
            return prices[address(CErc20(address(cToken)).underlying())];
        }
    }

    function setUnderlyingPrice(CToken cToken, uint underlyingPriceMantissa) public onlyAdmin {
        address asset = address(CErc20(address(cToken)).underlying());
        setDirectPrice(asset, underlyingPriceMantissa);
    }

    function setDirectPrice(address _asset, uint _price) public onlyAdmin {
        prices[_asset] = _price;
        emit PricePosted(_asset, prices[_asset], _price, _price);
    }

    function setDirectPrice(address[] memory _assets, uint[] memory _prices) public onlyAdmin {
        require(_assets.length > 0, "At least one asset price is required");
        require(_assets.length == _prices.length, "Assets and prices are not match");

        for (uint i = 0; i < _assets.length; i++) {
            prices[_assets[i]] = _prices[i];
            emit PricePosted(_assets[i], prices[_assets[i]], _prices[i], _prices[i]);
        }
    }

    function assetPrices(address asset) external view returns (uint) {
        return prices[asset];
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function addPriceAdmin(address newPriceAdmin) public onlyAdmin {
        priceAdmin[newPriceAdmin] = true;
        emit PriceAdminAdded(newPriceAdmin);
    }

    function removePriceAdmin(address newPriceAdmin) public onlyAdmin {
        priceAdmin[newPriceAdmin] = false;
        emit PriceAdminRemoved(newPriceAdmin);
    }
}

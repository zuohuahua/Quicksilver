pragma solidity ^0.5.16;

import "./compound/PriceOracle.sol";
import "./compound/CErc20.sol";
import "./IPriceCollector.sol";

contract QsPriceOracle is PriceOracle, IPriceCollector {
    mapping(address => uint) prices;
    address public priceAdmin;

    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);
    event PriceAdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    modifier onlyAdmin {
        require(msg.sender == priceAdmin, "Price Admin required.");
        _;
    }

    constructor() public {
            priceAdmin = msg.sender;
    }

    function getUnderlyingPrice(CToken cToken) public view returns (uint) {
        if (compareStrings(cToken.symbol(), "sELA") || compareStrings(cToken.symbol(), "sETH")) {
            return 1e18;
        } else {
            return prices[address(CErc20(address(cToken)).underlying())];
        }
    }

    function setUnderlyingPrice(CToken cToken, uint underlyingPriceMantissa) public onlyAdmin {
        address asset = address(CErc20(address(cToken)).underlying());
        setDirectPrice(asset, underlyingPriceMantissa);
    }

    function setDirectPrice(address asset, uint price) public onlyAdmin {
        emit PricePosted(asset, prices[asset], price, price);
        prices[asset] = price;
    }

    // v1 price oracle interface for use as backing of proxy
    function assetPrices(address asset) external view returns (uint) {
        return prices[asset];
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function transferPriceAdmin(address newAdmin) public onlyAdmin {
        require(newAdmin != address(0), "Ownable: new price admin is the zero address");
        emit PriceAdminTransferred(priceAdmin, newAdmin);
        priceAdmin = newAdmin;
    }
}

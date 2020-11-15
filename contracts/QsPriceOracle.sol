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

    function transferPriceAdmin(address newAdmin) public onlyAdmin {
        require(newAdmin != address(0), "Ownable: new price admin is the zero address");
        emit PriceAdminTransferred(priceAdmin, newAdmin);
        priceAdmin = newAdmin;
    }
}

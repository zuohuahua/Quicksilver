pragma solidity ^0.5.16;

import "./compound/PriceOracle.sol";
import "./compound/CErc20.sol";
import "./IPriceCollector.sol";
import "./SToken.sol";
import "./compound/SafeMath.sol";

contract QsPriceOracleV2 is PriceOracle, IPriceCollector {
    struct ErrorInfo {
        uint timestamp;
        uint previousPrice;
        uint errPrice;
        address priceAdmin;
    }
    mapping(address => uint) prices;
    mapping(address => bool) public priceAdmin;
    address public governance;
    mapping(address => ErrorInfo) public errorInfo;
    mapping(address => bool) public errorHappened;
    bool public paused = false;

    using SafeMath for uint;

    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);
    event GovernanceTransferred(address indexed previousGovernance, address indexed newGovernance);
    event PriceAdminAdded(address newAdmin);
    event PriceAdminRemoved(address newAdmin);
    event PriceAlert(address priceAdmin, address asset, uint previousPriceMantissa, uint newPriceMantissa);

    modifier onlyPriceAdmin {
        require(priceAdmin[msg.sender], "Price Admin required.");
        _;
    }

    modifier onlyGovernance {
        require(msg.sender == governance, "Governance required.");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    constructor() public {
        governance = msg.sender;
        priceAdmin[governance] = true;
    }

    function getUnderlyingPrice(CToken cToken) public view returns (uint) {
        if (SToken(address(cToken)).isNativeToken()) {
            return 1e18;
        } else {
            return prices[address(CErc20(address(cToken)).underlying())];
        }
    }

    function setUnderlyingPrice(CToken cToken, uint underlyingPriceMantissa) public onlyPriceAdmin {
        address asset = address(CErc20(address(cToken)).underlying());
        setDirectPrice(asset, underlyingPriceMantissa);
    }

    function isValidPrice(address _asset, uint _price) public view returns (bool) {
        // initial price is 0
        if (prices[_asset] == 0) return true;

        uint min = prices[_asset].div(2);
        uint max = prices[_asset].mul(2);

        return _price > min && _price < max;
    }

    function setDirectPrice(address _asset, uint _price) public onlyPriceAdmin whenNotPaused {
        uint previousPrice = prices[_asset];
        uint newPrice = _price;
        if (isValidPrice(_asset, _price)) {
            prices[_asset] = newPrice;
            emit PricePosted(_asset, previousPrice, newPrice,  prices[_asset]);
        } else {
            errorInfo[_asset] = ErrorInfo(block.timestamp, previousPrice, newPrice, msg.sender);
            errorHappened[_asset] = true;
            emit PriceAlert(msg.sender, _asset, previousPrice, newPrice);
        }
    }

    function setDirectPrice(address[] memory _assets, uint[] memory _prices) public onlyPriceAdmin whenNotPaused {
        require(_assets.length > 0, "At least one asset price is required");
        require(_assets.length == _prices.length, "Assets and prices are not match");

        for (uint i = 0; i < _assets.length; i++) {
            setDirectPrice(_assets[i], _prices[i]);
        }
    }

    function setPrice(address _asset, uint _price) private onlyPriceAdmin {
        uint previousPrice = prices[_asset];
        uint newPrice = _price;
        prices[_asset] = newPrice;
        emit PricePosted(_asset, previousPrice, newPrice,  prices[_asset]);
    }

    function setDirectPriceWithForce(address[] memory _assets, uint[] memory _prices) public onlyPriceAdmin {
        require(_assets.length > 0, "At least one asset price is required");
        require(_assets.length == _prices.length, "Assets and prices are not match");

        for (uint i = 0; i < _assets.length; i++) {
            setPrice(_assets[i], _prices[i]);
        }
    }

    function assetPrices(address asset) external view returns (uint) {
        return prices[asset];
    }

    function addPriceAdmin(address newPriceAdmin) public onlyGovernance {
        priceAdmin[newPriceAdmin] = true;
        emit PriceAdminAdded(newPriceAdmin);
    }

    function removePriceAdmin(address newPriceAdmin) public onlyGovernance {
        priceAdmin[newPriceAdmin] = false;
        emit PriceAdminRemoved(newPriceAdmin);
    }

    function setPaused(bool _paused) public onlyGovernance {
        paused = _paused;
    }

    function setErrorHappened(address asset, bool happened) public onlyGovernance {
        errorHappened[asset] = happened;
    }

    function transferGovernance(address newGovernance) public onlyGovernance {
        require(newGovernance != address(0), "Governance address should not be zero");
        emit GovernanceTransferred(governance, newGovernance);
        governance = newGovernance;
    }
}

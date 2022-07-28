// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "../interfaces/IPoolV3.sol";
import "../interfaces/LiquidityPoolInterfaces.sol";
import "../interfaces/IPoolAddressesProvider.sol";
import "hardhat/console.sol";
import "../libraries/PercentageMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract AaveWrapper {
    using PercentageMath for uint256;
    struct DEPOSITS {
        uint256 amount;
        uint256 price;
    }
    AggregatorV3Interface internal priceFeed;
    mapping(address => mapping(string => DEPOSITS)) public deposits;

    IPoolV2 public constant POOL =
        IPoolV2(address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9));

    IPoolAddressesProvider public constant POOL_ADDRESS_PROVIDER =
        IPoolAddressesProvider(
            address(0x6878e137738Db14E27c5972E03dB4a2C270Bc694)
        );
    IERC20 public constant SUPPLY_ASSET =
        IERC20(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)); // WETH
    IERC20 public constant BORROW_ASSET =
        IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)); // USDC


    constructor() {
        priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    }

     function getLatestPrice() public view returns (int) {
        (
            int price,
        ) = priceFeed.latestRoundData();
        return price;
    }

    function deposit(uint256 amount) public {
        SUPPLY_ASSET.approve(address(POOL), amount);
        ethPrice = getLatestPrice();
        deposits[msg.sender]["ETH"]["amount"] = amount;
        deposits[msg.sender]["ETH"]["price"] = ethPrice;
        POOL.supply(address(SUPPLY_ASSET), amount, address(this), 0);
    }

}
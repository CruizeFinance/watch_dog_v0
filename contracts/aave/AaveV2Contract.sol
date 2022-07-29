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
    struct ASSETS {
        address assetAddress;
        address priceFeedAddress;
    }
    AggregatorV3Interface internal priceFeed;
    mapping(address => mapping(string => DEPOSITS)) public deposits;
    mapping(string => ASSETS) public supplyAssets;
    IPoolV2 public constant POOL =
        IPoolV2(address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9));

    IPoolAddressesProvider public constant WETHGATEWAY =
        IPoolAddressesProvider(
            address(0xcc9a0B7c43DC2a5F023Bb9b738E45B0Ef6B06E04)
        );
    IERC20 public constant BORROW_ASSET =
        IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)); // USDC

    function getLatestPrice(address priceAddress) public view returns (int) {
        priceFeed = AggregatorV3Interface(priceAddress);
        (
            int price,
        ) = priceFeed.latestRoundData();
        return price;
    }

    function addSupplyAsset(string assetName, address assetAddress, address priceFeedAddress) public onlyOwner {
        supplyAssets[assetName]["assetAddress"] = assetAddress;
        supplyAssets[assetName]["priceFeedAddress"] = priceFeedAddress;
    }

    function deposit(uint256 amount, string memory assetName) public payable {
        require(supplyAssets[assetName].assetAddress != address(0), "1: Asset not allowed.");
        assetPrice = getLatestPrice(supplyAssets[assetName.priceAddress]);
        deposits[msg.sender][assetName]["amount"] = amount;
        deposits[msg.sender][assetName]["price"] = assetPrice;
        if (msg.value > 0) {
            // way to call a payable function
            WETHGATEWAY.depositEth(address(POOL), address(this), 0){value: msg.value};
        }
        else {
            SUPPLY_ASSET.transferFrom(msg.sender, address(this), amount);
            SUPPLY_ASSET.approve(address(POOL), amount);
            POOL.deposit(address(SUPPLY_ASSET), amount, address(this), 0);
        }
    }

}
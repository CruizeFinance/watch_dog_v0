// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "../interfaces/LiquidityPoolInterfaces.sol";
import "../interfaces/IPoolAddressesProvider.sol";
import "../libraries/PercentageMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract AaveWrapper {
    using PercentageMath for uint256;
    struct Desposits {
        uint256 amount;
        uint256 price;
    }
    struct Assets {
        address assetAddress;
        address priceFeedAddress;
    }
    AggregatorV3Interface internal priceFeed;
    address aaveV2LendingPool = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address usdcContractAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    mapping(address => mapping(string => Deposits)) public deposits;
    mapping(string => Assets) public supplyAssets;

    IPoolV2 public constant POOL =
        IPoolV2(address(aaveV2LendingPool));

    IPoolAddressesProvider public constant WETHGATEWAY =
        IPoolAddressesProvider(
            address(0xcc9a0B7c43DC2a5F023Bb9b738E45B0Ef6B06E04)
        );
    IERC20 public constant BORROW_ASSET =
        IERC20(address(usdcContractAddress)); // USDC

    function getLatestPrice(address priceAddress) public view returns (int) {
        priceFeed = AggregatorV3Interface(priceAddress);
        (
            int price,
        ) = priceFeed.latestRoundData();
        return price;
    }

    function addSupplyAsset(string assetName, address assetAddress, address priceFeedAddress) public onlyOwner {
        supplyAssets[assetName].assetAddress = assetAddress;
        supplyAssets[assetName].priceFeedAddress = priceFeedAddress;
    }

    function deposit(uint256 amount, string memory assetName) public payable {
        require(supplyAssets[assetName].assetAddress != address(0), "1: Asset not allowed.");
        assetPrice = getLatestPrice(supplyAssets[assetName].priceFeedAddress);
        deposits[msg.sender][assetName].amount = amount;
        deposits[msg.sender][assetName].price = assetPrice;
        if (msg.value > 0) {
            // way to call a payable function
            WETHGATEWAY.depositEth(address(POOL), address(this), 0){value: msg.value};
        }
        else {
            require(amount > 0, "1: Amount cannot be zero");
            IERC20 supplyAsset = IERC20(address(supplyAssets[assetName].assetAddress));
            supplyAsset.transferFrom(msg.sender, address(this), amount);
            supplyAsset.approve(address(POOL), amount);
            POOL.deposit(address(supplyAsset), amount, address(this), 0);
        }
    }

    function borrow(string assetName) public {
        userData = POOL.getUserAccountData(address(this));
        assetPrice = getLatestPrice(supplyAssets[assetName].priceFeedAddress);
        borrowAmount = ((ethPrice * userData.availableBorrowsETH) / 10**20) * 20 / 100;
        POOL.borrow(usdcContractAddress, borrowAmount, 2, 0, address(this));
    }

    function repay() public {
        POOL.repay(usdcContractAddress, type(uint256).max, 2, address(this));
    }

    function withdraw(string assetName) public {
        POOL.withdraw(supplyAsset[assetAddress].assetAddress, type(uint256).max, address(this));
    }

}

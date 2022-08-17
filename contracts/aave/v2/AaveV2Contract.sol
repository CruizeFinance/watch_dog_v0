// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "hardhat/console.sol";
import "../../libraries/Errors.sol";
import "../../interfaces/IPoolV2.sol";
import "../../interfaces/IWETHGateway.sol";
import "../../libraries/PercentageMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @author CRUIZE.
 * @title Cruize AaveV2Wrapper.
 * @notice Aave version 2 contract integration to borrow a 20% loan against the user's deposited asset.
 * 1 - User's deposited asset from the asset pool is deposited into Aave.
 * 2 - A 20% loan is borrowed in USDC.
 * 3 - The borrowed USDC is deposited into our USDC pool.
 */
contract AaveV2Wrapper is Ownable, ReentrancyGuard {
    using PercentageMath for uint256;

    //----------------------------//
    //        State Variable      //
    //----------------------------//
    mapping(address => address) public depositAssets;

    uint256 public borrowRatio = 200; // 20% of 1000
    uint256 private constant USD_DECIMALS = 8;
    uint256 private constant ETH_DECIMALS = 18;

    IPoolV2 internal constant POOL =
        IPoolV2(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    IWETHGateway internal constant WETHGATEWAY =
        IWETHGateway(0xcc9a0B7c43DC2a5F023Bb9b738E45B0Ef6B06E04);

    IERC20 internal constant BORROW_ASSET =
        IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC

    //----------------------------//
    //          Events            //
    //----------------------------//

    event AddAsset(address indexed _asset, address _oracle);
    event BorrowRatioChanged(uint256 indexed ratio);

   

    //----------------------------//
    //       View Functions       //
    //----------------------------//

    /**
     * @dev fetch the latest price of the asset from oracle
     * @param _asset address for which we need price
     */
    function getLatestPrice(address _asset) internal view returns (int256 price) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_asset);
        (, price, , , ) = priceFeed.latestRoundData();
    }
  
    function nomalize(uint256 _amount) internal pure returns (uint256) {
        return _amount * 10**(ETH_DECIMALS - USD_DECIMALS);
    }

    //----------------------------//
    //     Mutation Functions     //
    //----------------------------//

    function addDepositAsset(
        address asset,
        address priceOracle
    ) public onlyOwner  {
         require(depositAssets[asset] == address(0));
        depositAssets[asset] = priceOracle;
        emit AddAsset(asset,asset);
    }

    /**
     * @dev Users will deposit their assets in pool
     * @param asset will be asset name like ETH or BTC
     * @param amount will be the deposited amount
     */
    function deposit( address asset,uint256 amount) public  onlyOwner nonReentrant payable {
        require(
            depositAssets[asset] != address(0),
            Errors.ASSET_NOT_ALLOWED
        );
        if (msg.value > 0) {
            WETHGATEWAY.depositETH{value: msg.value}(
                address(POOL),
                address(this),
                0
            );
        } else {
            require(amount > 0, Errors.ZERO_AMOUNT);
            IERC20 supplyAsset = IERC20(asset);
            //wrong this 
            supplyAsset.transferFrom(msg.sender, address(this), amount);
            supplyAsset.approve(address(POOL), amount);
            POOL.deposit(address(supplyAsset), amount, address(this), 0);
        }
    }

    /**
     * @dev Cruize will borrow on behalf of user
     * @param asset will be asset name like ETH or BTC
     */

    function borrow(address asset) public onlyOwner nonReentrant {
        (, , uint256 availableBorrowsETH, , , ) = POOL.getUserAccountData(
            address(this)
        );

        int256 assetPrice = getLatestPrice(depositAssets[asset]);
        uint256 availableBorrowAmountIn18Decimals = (nomalize(
            uint256(assetPrice)
        ) * availableBorrowsETH) / 1e18;
        uint256 availableBorrowAmountIn6Decimals = availableBorrowAmountIn18Decimals /
                1e12;
        uint256 borrowAmount = (availableBorrowAmountIn6Decimals *
            borrowRatio) / 1000;
           
        POOL.borrow(address(BORROW_ASSET), borrowAmount, 2, 0, address(this));
    }

    /**
     * @dev Cruize pool will repay the debt amount
     */
    function repay(uint256 amount) public onlyOwner  nonReentrant {
        BORROW_ASSET.approve(address(POOL), amount);
     
        POOL.repay(address(BORROW_ASSET), amount, 2, address(this));
    }


    /**
     * @dev Criuze will withdraw collateral amount
     * @param asset will be asset name like ETH or BTC
     */
    function withdraw(address asset,uint256 amount) public onlyOwner nonReentrant {
  
        (, uint256 debt, , , , ) = POOL.getUserAccountData(address(this));
        POOL.withdraw(
            asset,
            amount,
            address(this)
        );
    }

    function changeBorrowRatio(uint256 ratio) public onlyOwner {
        require(ratio != borrowRatio, Errors.BORROW_NOT_CHANGED);
        borrowRatio = ratio;
        emit BorrowRatioChanged(ratio);
    }
}

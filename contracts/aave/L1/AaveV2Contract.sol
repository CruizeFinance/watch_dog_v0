// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "hardhat/console.sol";
import "../../libraries/Errors.sol";
import "../../interfaces/IPoolV2.sol";
import "../../interfaces/IWETHGateway.sol";
import "../../libraries/PercentageMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @author CRUIZE.
 * @title Cruize AaveV2Wrapper.
 * @notice Aave version 2 contract integration to borrow a 20% loan against the user's deposited asset.
 * 1 - User's deposited asset from the asset pool is deposited into Aave.
 * 2 - A 20% loan is borrowed in USDC.
 * 3 - The borrowed USDC is deposited into our USDC pool.
 */
contract AaveV2Wrapper is Ownable, ReentrancyGuardUpgradeable {
    using PercentageMath for uint256;

    //----------------------------//
    //        State Variable      //
    //----------------------------//
    mapping(address => address) public depositAssets;

    uint256 public borrowRatio = 200; // 20% of 1000
    uint256 private constant USD_DECIMALS = 8;
    uint256 private constant ETH_DECIMALS = 18;

    IPoolV2 public constant POOL =
        IPoolV2(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    IWETHGateway public constant WETHGATEWAY =
        IWETHGateway(0xcc9a0B7c43DC2a5F023Bb9b738E45B0Ef6B06E04);

    IERC20 public constant BORROW_ASSET =
        IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC

    //----------------------------//
    //          Events            //
    //----------------------------//

    event AddAsset(address indexed _asset, address _oracle);
    event BorrowRatioChanged(uint256 indexed ratio);

    //----------------------------//
    //          Modifiers         //
    //----------------------------//

    modifier isValid(address _asset) {
        require(depositAssets[_asset] == address(0));
        _;
    }

    //----------------------------//
    //       View Functions       //
    //----------------------------//

    /**
     * @dev fetch the latest price of the asset from oracle
     * @param _asset address for which we need price
     */
    function getLatestPrice(address _asset) public view returns (int256 price) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_asset);
        (, price, , , ) = priceFeed.latestRoundData();
    }
  
    function nomalize(uint256 amount) public view returns (uint256) {
        return amount * 10**(ETH_DECIMALS - USD_DECIMALS);
    }

    //----------------------------//
    //     Mutation Functions     //
    //----------------------------//


    function addDepositAsset(
        address _asset,
        address _priceOracle
    ) public onlyOwner isValid( _asset) {
        
        depositAssets[_asset] = _priceOracle;
        emit AddAsset(_asset,_priceOracle);
    }

    /**
     * @dev Users will deposit their assets in pool
     * @param _asset will be asset name like ETH or BTC
     * @param _amount will be the deposited amount
     */
    function deposit( address _asset,uint256 _amount) public nonReentrant payable {
        require(
            depositAssets[_asset] != address(0),
            Errors.ASSET_NOT_ALLOWED
        );

        int256 assetPrice = getLatestPrice(depositAssets[_asset]);

        if (msg.value > 0) {
            WETHGATEWAY.depositETH{value: msg.value}(
                address(POOL),
                address(this),
                0
            );
        } else {
            require(_amount > 0, Errors.ZERO_AMOUNT);
            IERC20 supplyAsset = IERC20(_asset);
            //wrong this 
            supplyAsset.transferFrom(msg.sender, address(this), _amount);
            supplyAsset.approve(address(POOL), _amount);
            POOL.deposit(address(supplyAsset), _amount, address(this), 0);
        }
    }

    /**
     * @dev Cruize will borrow on behalf of user
     * @param _asset will be asset name like ETH or BTC
     */

    function borrow(address _asset) public nonReentrant {
        (, , uint256 availableBorrowsETH, , , ) = POOL.getUserAccountData(
            address(this)
        );

        int256 assetPrice = getLatestPrice(depositAssets[_asset]);
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
    function repay() public nonReentrant {
        BORROW_ASSET.approve(address(POOL), type(uint256).max);
     
        POOL.repay(address(BORROW_ASSET), type(uint256).max, 2, address(this));
    }

    /**
     * @dev Criuze will withdraw collateral amount
     * @param _asset will be asset name like ETH or BTC
     */
    function withdraw(address _asset) public nonReentrant {
  
        (, uint256 debt, , , , ) = POOL.getUserAccountData(address(this));
        POOL.withdraw(
            _asset,
            type(uint256).max,
            address(this)
        );
    }


    function changeBorrowRatio(uint256 ratio) public onlyOwner {
        require(ratio != borrowRatio, Errors.BORROW_NOT_CHANGED);
        borrowRatio = ratio;
        emit BorrowRatioChanged(ratio);
    }
}

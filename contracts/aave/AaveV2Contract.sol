// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "../libraries/Errors.sol";
import "../interfaces/IPoolV2.sol";
import "../interfaces/IWETHGateway.sol";
import "../libraries/PercentageMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract AaveWrapper is Ownable {
    using PercentageMath for uint256;

    struct Deposits {
        uint256 amount;
        uint256 price;
    }

    struct Assets {
        address asset;
        address priceOracle;
    }

    //----------------------------//
    //        State Variable      //
    //----------------------------//
    mapping(address => mapping(address => Deposits)) public deposits;
    mapping(address => address) public depositAssets;

    uint256 public BorrowRatio = 200; // 20% of 1000
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

    /**
     * @dev Only admin can add new supply assets and their oracles
     * @param _asset will be address of the asset
     * @param _priceOracle will the chainlink asset price oracle
     * for fetching asset current price
     */
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
    function deposit( address _asset,uint256 _amount) public payable {
        require(
            depositAssets[_asset] != address(0),
            Errors.ASSET_NOT_ALLOWED
        );

        int256 assetPrice = getLatestPrice(depositAssets[_asset]);

        deposits[msg.sender][_asset].amount = _amount;
        deposits[msg.sender][_asset].price = uint256(assetPrice);

        if (msg.value > 0) {
            WETHGATEWAY.depositETH{value: msg.value}(
                address(POOL),
                address(this),
                0
            );
        } else {
            require(_amount > 0, Errors.ZERO_AMOUNT);
            IERC20 supplyAsset = IERC20(_asset);
            supplyAsset.transferFrom(msg.sender, address(this), _amount);
            supplyAsset.approve(address(POOL), _amount);
            POOL.deposit(address(supplyAsset), _amount, address(this), 0);
        }
    }

    /**
     * @dev Cruize will borrow on behalf of user
     * @param _asset will be asset name like ETH or BTC
     */
    function borrow(address _asset) public {
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
            BorrowRatio) / 1000;
        POOL.borrow(address(BORROW_ASSET), borrowAmount, 2, 0, address(this));
    }

    /**
     * @dev Cruize pool will repay the debt amount
     */
    function repay() public {
        BORROW_ASSET.approve(address(POOL), type(uint256).max);
        POOL.repay(address(BORROW_ASSET), type(uint256).max, 2, address(this));
    }

    /**
     * @dev Criuze will withdraw collateral amount
     * @param _asset will be asset name like ETH or BTC
     */
    function withdraw(address _asset) public {
        (, uint256 debt, , , , ) = POOL.getUserAccountData(address(this));
        POOL.withdraw(
            _asset,
            type(uint256).max,
            address(this)
        );
    }

    /**
     * @dev only owner can change the borrow ratio
     * @param ratio percentage in 1000 bips i.e 100 == 10% of 1000
     */
    function changeBorrowRatio(uint256 ratio) public onlyOwner {
        require(ratio != BorrowRatio, Errors.BORROW_NOT_CHANGED);
        BorrowRatio = ratio;
        emit BorrowRatioChanged(ratio);
    }
}

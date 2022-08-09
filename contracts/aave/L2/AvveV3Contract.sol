pragma solidity ^0.8.10;
import "hardhat/console.sol";
import "../../libraries/Errors.sol";
import "../../interfaces/IPoolV3.sol";
import "../../interfaces/IWETHGateway.sol";
import "../../libraries/PercentageMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @author CRUIZE.
 * @title Cruize AaveV2Wrapper.
 * @notice Aave version 3 contract integration to borrow a 20% loan against the user's deposited asset.
 * 1 - User's deposited asset from the asset pool is deposited into Aave.
 * 2 - A 20% loan is borrowed in USDC.
 * 3 - The borrowed USDC is deposited into our USDC pool.
 */
contract AaveV3Wrapper is Ownable, ReentrancyGuard {
    using PercentageMath for uint256;

    //----------------------------//
    //        State Variable      //
    //----------------------------//
    mapping(address => address) public depositAssets;

    uint256 public borrowRatio = 200; // 20% of 1000
    uint256 private constant USD_DECIMALS = 8;
    uint256 private constant ETH_DECIMALS = 18;

    IPoolV3 public constant POOL =
        IPoolV3(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    IWETHGateway public constant WETHGATEWAY =
        IWETHGateway(0xC09e69E79106861dF5d289dA88349f10e2dc6b5C);

    IERC20 public constant BORROW_ASSET =
        IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8); // USDC

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
     * @dev Only owner can add new assets that the contract will support for staking
     * @param _asset will be address of the asset
     * @param _priceOracle will the chainlink asset price oracle
     * event AddAsset(_asset: 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2, _priceOracle: 0xAc559F25B1619171CbC396a50854A3240b6A4e99)
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
    function depositETH( address _asset,uint256 _amount) public nonReentrant payable {
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
            supplyAsset.transferFrom(msg.sender, address(this), _amount);
            supplyAsset.approve(address(POOL), _amount);
            POOL.supply(address(supplyAsset), _amount, address(this), 0);
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

    /**
     * @dev only owner can change the borrow ratio
     * @param ratio percentage in 1000 bips i.e 100 == 10% of 1000
     * event BorrowRatioChanged(ratio = 200)
     */
    function changeBorrowRatio(uint256 ratio) public onlyOwner {
        require(ratio != borrowRatio, Errors.BORROW_NOT_CHANGED);
        borrowRatio = ratio;
        emit BorrowRatioChanged(ratio);
    }
}
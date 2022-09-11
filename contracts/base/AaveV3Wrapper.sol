// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/Errors.sol";
import "../interfaces/IPoolV3.sol";
import "../interfaces/IWETHGateway.sol";
import "../interfaces/LiquidityPoolInterfaces.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @author CRUIZE.
 * @title Cruize AaveV2Wrapper.
 * @notice AaveV2Wrapper contract is an integration with aave(ETHEREUM-MAINNET) 
 * to borrow a 25% loan against the user's deposited asset.
 * 1 - User's deposited 90% amount will be deposited into Aave.
 * 2 - Remaining 10% amount will be transferred cruize wallet
 * 3 - A 25% loan is borrowed in USDC and transferred to the cruize wallet.
 */
contract AaveV2Wrapper is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;

    //----------------------------//
    //        State Variable      //
    //----------------------------//

    uint256 public priceFloor;
    uint256 public constant BASE = 10000;

    address public crContract;
    address public cruize_wallet;
    uint256 public borrowRatio = 2500; // 25% of 1000
    uint256 public constant aaveDefaulLTV = 8250; // 82.5% of 1000
    uint256 private constant USD_DECIMALS = 8;
    uint256 private constant ETH_DECIMALS = 18;

    //----------------------------//
    //        Mappings            //
    //----------------------------//

    // reserveToken => crToken
    mapping(address => address) public lpTokens;
    // reserveToken => oracles
    mapping(address => address) public oracles;


    IPoolV3 internal constant POOL =
        IPoolV3(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

    IWETHGateway internal constant WETHGATEWAY =
        IWETHGateway(0xC09e69E79106861dF5d289dA88349f10e2dc6b5C);

    IERC20 internal constant BORROW_ASSET =
        IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8); // USDC

    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    //----------------------------//
    //          Events            //
    //----------------------------//

    event AddAsset(address indexed _asset, address _oracle);
    event BorrowRatioChanged(uint256 indexed ratio);
    event WithdrawEvent(
        address indexed asset,
        address indexed account,
        uint256 amount
    );
    event DepositEvent(address indexed account, uint256 amount);
    event CreateToken(
        address indexed tokenAddress,
        string tokenName,
        string tokenSymbol,
        uint8 decimal
    );

    //----------------------------//
    //       View Functions       //
    //----------------------------//

    /**
     * @dev fetch the latest price of the asset from oracle
     * @param oracle address for which we need price
     */
    function getLatestPrice(address oracle)
        internal
        view
        returns (int256 price)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(oracle);
        (, price, , , ) = priceFeed.latestRoundData();
    }

    function normalize(uint256 _amount) internal pure returns (uint256) {
        return _amount * 10**(ETH_DECIMALS - USD_DECIMALS);
    }

    function calculateBorrow(address reserve, uint256 amount)
        internal
        view
        returns (uint256)
    {
        if (reserve == ETH) reserve = WETH;
        int256 assetPrice = getLatestPrice(oracles[reserve]);
        uint256 availableBorrowAmountIn18Decimals = (normalize(uint256(assetPrice).mul(amount).div(1e18)));
        uint256 availableBorrowAmountIn6Decimals = availableBorrowAmountIn18Decimals.div(1e12);
        uint256 aaveLTV = availableBorrowAmountIn6Decimals.mul(aaveDefaulLTV).div(BASE);
        return aaveLTV.mul(borrowRatio).div(BASE);
    }

    //-----------------------------//
    // Internal Mutation Functions //
    //-----------------------------//

    function depositETH(uint256 amountToAave,uint256 amountToCruize) internal {
        WETHGATEWAY.depositETH{value: amountToAave}(address(POOL), address(this), 0);
        payable(cruize_wallet).transfer(amountToCruize);
    }

    function depositERC20(address reserve, uint256 amountToAave,uint256 amountToCruize) internal {
        IERC20 token = IERC20(reserve);
        require(token.transferFrom(msg.sender, address(this), amountToAave));
        require(token.approve(address(POOL), amountToAave));
        POOL.deposit(address(token), amountToAave, address(this), 0);
        require(token.transferFrom(msg.sender,cruize_wallet, amountToCruize));
    }

    function depositToAave(address reserve, uint256 amount)
        internal
        returns (uint256)
    {
        if ((amount > 0 && msg.value != 0) || (msg.value > 0 && amount != 0))
            revert ValuesNotMatched();
        if (reserve == address(0)) revert ZeroAddress();
        if (amount == 0 && msg.value == 0) revert ZeroAmount();
        if (lpTokens[reserve] == address(0)) revert AssetNotAllowed();
        if (msg.value > 0) amount = msg.value;
        
        uint256 amountToCruize = (amount * 1000) / BASE;
        uint256 amountToAave = amount - amountToCruize;

        if (reserve == ETH && msg.value > 0) {
            depositETH(amountToAave,amountToCruize);
        } else {
            depositERC20(reserve, amountToAave,amountToCruize);
        }
        ILPtoken(lpTokens[reserve]).mint(msg.sender, amount);
        emit DepositEvent(msg.sender, amount);
        return amountToAave;
    }

    function borrow(address reserve, uint256 amount) internal {
        uint256 borrowAmount = calculateBorrow(reserve, amount);
        POOL.borrow(address(BORROW_ASSET), borrowAmount, 2, 0, address(this));
        // transfer loan to cruize wallet
        require(BORROW_ASSET.transfer(cruize_wallet, borrowAmount));
    }

    function withdrawETH(
        uint256 amount,
        address to
    ) internal {
        DataTypes.ReserveDataV3 memory reserve = POOL.getReserveData(WETH);
        require(IERC20(reserve.aTokenAddress).approve(address(WETHGATEWAY), amount));
        WETHGATEWAY.withdrawETH(address(POOL), amount, to);
    }

    function withdrawERC20(
        address asset,
        uint256 amount,
        address to
    ) internal {
        DataTypes.ReserveDataV3 memory reserve = POOL.getReserveData(asset);
        require(IERC20(reserve.aTokenAddress).approve(address(WETHGATEWAY), amount));
        POOL.withdraw(asset, amount, to);
    }

    function withdrawFromAave(
        address asset,
        uint256 amount,
        address to
    ) internal {
        if (asset == ETH) {
            withdrawETH(amount, to);
        } else {
            withdrawERC20(asset, amount, to);
        }
    }

    function changeBorrowRatio(uint256 ratio) public onlyOwner {
        if (ratio == borrowRatio) revert SameBorrowRatio();
        borrowRatio = ratio;
        emit BorrowRatioChanged(ratio);
    }
}
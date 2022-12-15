// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IUSDC.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IOracle.sol";
import "../interfaces/IPoolV2.sol";
import "../interfaces/ICRToken.sol";
import "../libraries/MathUtils.sol";
import "../libraries/WadRayMath.sol";
import "../interfaces/IAaveOracle.sol";
import "../interfaces/ISwapRouter.sol";
import "../interfaces/IWETHGateway.sol";
import "../interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "hardhat/console.sol";

interface aToken {
    function UNDERLYING_ASSET_ADDRESS() external returns (address);

    function scaledBalanceOf(address user) external view returns (uint256);
}

/**
 * @author CRUIZE.
 * @title Cruize AaveV2Wrapper.
 * @notice AaveV2Wrapper contract is an integration with aave(ETHEREUM-MAINNET)
 * Its main functionality to deposit, repay and withdraw from aave on behalf
 * of cruize contract.
 * Some key features of this contract.
 * 1 - Deposit user asset amount in aave lending pool.
 * 2 - Borrow a {borrowRatio}% loan against the user's deposited asset.
 * 3 - User's deposited 90% amount will be deposited into Aave.
 * 4 - A 15% loan is borrowed in USDC and transferred to the dydx account.
 */
contract AaveV2Wrapper is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;
    using WadRayMath for uint256;

    //----------------------------//
    //        State Variable      //
    //----------------------------//

    address public crContract;
    address public dydxWallet;
    uint256 public borrowRatio = 1500; // 15% of 10000

    //----------------------------//
    //    Constant Variable       //
    //----------------------------//
    uint256 public constant VARIABLE_RATE = 2;
    uint256 public constant BASE = 10000;
    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant USD_DECIMALS = 8;
    uint256 public constant ETH_DECIMALS = 18;
    address public constant POOL = 0x4bd5643ac6f66a5237E18bfA7d47cF22f1c9F210;
    address public constant WETH_GATEWAY_ADDR =
        0x3bd3a20Ac9Ff1dda1D99C0dFCE6D65C4960B3627;
    address public constant USDC = 0x9FD21bE27A2B059a288229361E2fA632D8D2d074;
    address public constant WETH = 0xCCa7d1416518D095E729904aAeA087dBA749A4dC;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant USDC_TEST =
        0x8D49213C586Dc6D38dC219DC404713336d88d1af;
    address public constant ORACLE = 0xC27a285E0d0C0738bC9FD505052e6c2b6177F873;
    address public constant AAVE_ORACLE =
        0x2cb0d5755436ED904D7D0fbBACc6176286c55667;

    //----------------------------//
    //        Mappings            //
    //----------------------------//

    // reserveToken => crToken
    mapping(address => address) public crTokens;
    // reserveToken => oracles
    mapping(address => address) public oracles;
    // asset => shareInPool
    mapping(address => uint256) public pools;
    //----------------------------//
    //        Address             //
    //----------------------------//

    IOracle internal TrustedOracle = IOracle(ORACLE);

    // Aave lending pool address
    IPoolV2 internal TrustedAavePool = IPoolV2(POOL);

    IERC20 internal TrustedBorrowAsset = IERC20(USDC);

    // Aave Price Oracle
    IAaveOracle internal TrustedAaveOracle = IAaveOracle(AAVE_ORACLE);

    // Aave WETH gateway to deposit and withdraw ETH
    IWETHGateway internal TrustedWethGateway = IWETHGateway(WETH_GATEWAY_ADDR);

    //----------------------------//
    //          Errors            //
    //----------------------------//
    error ZeroAmount();
    error ZeroAddress();
    error AssetNotAllowed();
    error AssetAlreadyExists();
    error SameBorrowRatio();
    error NotEnoughBalance();
    error TransferFailed();
    error InvalidDeposit();
    //----------------------------//
    //          Events            //
    //----------------------------//

    event BorrowRatioChanged(uint256 indexed ratio);
    event WithdrawEvent(
        address indexed asset,
        uint256 amount,
        bool isPriceFloor
    );
    event DepositEvent(address indexed asset, address account, uint256 amount);
    event CreateTokenEvent(
        address indexed asset,
        address indexed crToken,
        string name,
        string symbol,
        uint8 decimal
    );
    event Mint(address indexed from, uint256 value, uint256 index);

    modifier isApproved(IERC20 _token) {
        if (
            _token.allowance(address(this), ROUTER) <
            _token.balanceOf(address(this))
        ) require(_token.approve(ROUTER, type(uint256).max));
        _;
    }

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
        price = priceFeed.latestAnswer();
    }

    /**
     * @dev Convert given amount to USD decimals
     * @param amount asset amount
     * @param decimals asset decimals
     * @return amount in 6 decimals
     */
    function toUSDCDecimals(uint256 amount, uint256 decimals)
        internal
        pure
        returns (uint256)
    {
        return
            amount.mul(pow(USDC_DECIMALS)).div(pow(decimals.add(USD_DECIMALS)));
    }

    function pow(uint256 power) internal pure returns (uint256) {
        return 10**power;
    }

    /**
     * @dev Return the price of the given asset in USD
     * @param asset asset address
     */
    function priceOf(address asset) public view returns (uint256) {
        return uint256(getLatestPrice(oracles[asset]));
    }

    /**
     * @dev Return the price of the given asset in ETH
     * @param asset asset address
     */
    function priceInEth(address asset) internal view returns (uint256) {
        if (asset == ETH) asset = WETH;
        return TrustedAaveOracle.getAssetPrice(asset);
    }

    function priceFloorOf(address asset) public view returns (uint256) {
        if (asset == ETH || asset == WETH) return TrustedOracle.eth();
        return TrustedOracle.btc();
    }

    /**
     * @dev Calculate the brrow amount in USDC for the given 90% amount
     * of asset.
     * @param asset asset address
     * @param amount asset amount
     */
    function calculateBorrow(address asset, uint256 amount)
        internal
        view
        returns (uint256)
    {
        uint256 priceFloor = priceFloorOf(asset);
        uint256 amountInUsd = amount.mul(priceFloor);
        uint256 amountInUsdcDecimals = toUSDCDecimals(
            amountInUsd,
            decimalsOf(asset)
        );
        // 0.9 * 0.15 => 0.1350
        // slither-disable-next-line divide-before-multiply
        return amountInUsdcDecimals.mul(1350).div(BASE);
    }

    /**
     * @dev This function will return the balance of the give asset
     * @param asset address of the asset
     */
    function balanceOf(address asset) internal view returns (uint256) {
        return
            asset == ETH
                ? address(this).balance
                : IERC20(asset).balanceOf(address(this));
    }

    /**
     * @dev This function will return decimals of the give asset
     * @param asset address of the asset
     */
    function decimalsOf(address asset) internal view returns (uint256) {
        return asset != ETH ? ICRToken(asset).decimals() : ETH_DECIMALS;
    }

    /**
     * @dev This function will return the given amount to the given asset decimals
     * @param asset address of the asset
     * @param amount amount of the asset
     * @return converted amount into the given asset decimals
     */
    function toETH(address asset, uint256 amount)
        internal
        view
        returns (uint256)
    {
        return
            Math.mulDiv(
                priceInEth(asset),
                amount,
                pow(decimalsOf(asset)),
                Math.Rounding.Zero
            );
    }

    /**
     * @dev This function will convert amount into the eth decimals
     * @param asset address of the asset
     * @param amount amount of the asset
     * @return converted amount into the eth decimals
     */
    function fromETH(address asset, uint256 amount)
        internal
        view
        returns (uint256)
    {
        return
            Math.mulDiv(
                amount,
                pow(decimalsOf(asset)),
                priceInEth(asset),
                Math.Rounding.Zero
            );
    }
    //-----------------------------//
    // Internal Mutation Functions //
    //-----------------------------//

    /**
     * @dev Deposit the given amount of ETH to the AAVE pool
     * @param amount ETH amount
     */
    function depositETH(uint256 amount) internal {
        // slither-disable-next-line reentrancy-benign
        TrustedWethGateway.depositETH{value: amount}(
            address(TrustedAavePool),
            address(this),
            0
        );
    }

    /**
     * @dev deposit the given amount of asset to the AAVE pool
     * @param asset asset address
     * @param amountToAave asset amount
     */
    function depositERC20(address asset, uint256 amountToAave) internal {
        IERC20 token = IERC20(asset);
        require(token.approve(address(TrustedAavePool), amountToAave));
        TrustedAavePool.deposit(asset, amountToAave, address(this), 0);
    }

    /**
     * @dev deposit given amount erc20 token asset to the AAVE pool
     * @param asset asset address
     * @param amount asset amount
     */
    function depositToAave(address asset, uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();
        if (asset == address(0)) revert ZeroAddress();
        if (crTokens[asset] == address(0)) revert AssetNotAllowed();

        if (msg.value > 0) amount = msg.value;
        // adding user amount in the given pool for later share calculation
        pools[asset] = pools[asset].add(amount);

        if (asset == ETH && msg.value > 0) {
            depositETH(amount);
        } else {
            if (msg.value != 0) revert InvalidDeposit();
            IERC20 token = IERC20(asset);
            // Pull all the given amount from the user address
            require(token.transferFrom(msg.sender, address(this), amount));
            depositERC20(asset, amount);
        }
        DataTypes.ReserveDataV2 memory reserve = TrustedAavePool.getReserveData(
            asset
        );
        ICRToken(crTokens[asset]).mint(
            msg.sender,
            amount,
            reserve.liquidityIndex
        );
        emit DepositEvent(asset, msg.sender, amount);
    }

    /**
     * @dev borrow given amount from AAVE pool
     * @param asset asset address
     * @param amount asset amount
     */
    function borrow(address asset, uint256 amount) internal {
        uint256 borrowAmount = calculateBorrow(asset, amount);
        TrustedAavePool.borrow(
            USDC,
            borrowAmount,
            VARIABLE_RATE,
            0,
            address(this)
        );
        IUSDC(USDC).mint(borrowAmount.add(borrowAmount.mul(20).div(100)));
        // transfer loan to cruize wallet
        if (!TrustedBorrowAsset.transfer(dydxWallet, borrowAmount))
            revert TransferFailed();
    }

    /**
     * @dev withdraw ETH from AAVE pool
     * @param amount asset amount
     * @param to receiving address
     */
    function withdrawETH(uint256 amount, address to) internal {
        DataTypes.ReserveDataV2 memory asset = TrustedAavePool.getReserveData(
            WETH
        );
        if (
            IERC20(asset.aTokenAddress).allowance(
                address(this),
                address(TrustedWethGateway)
            ) < amount
        )
            require(
                IERC20(asset.aTokenAddress).approve(
                    address(TrustedWethGateway),
                    type(uint256).max
                )
            );
        TrustedWethGateway.withdrawETH(address(TrustedAavePool), amount, to);
    }

    /**
     * @dev withdraw ERC20 tokens from AAVE pool
     * @param asset asset address
     * @param amount asset amount
     * @param to receiving address
     */
    function withdrawERC20(
        address asset,
        uint256 amount,
        address to
    ) internal {
        DataTypes.ReserveDataV2 memory reserve = TrustedAavePool.getReserveData(
            asset
        );
        if (
            IERC20(reserve.aTokenAddress).allowance(
                address(this),
                address(TrustedAavePool)
            ) < amount
        )
            require(
                IERC20(reserve.aTokenAddress).approve(
                    address(TrustedAavePool),
                    type(uint256).max
                )
            );
        // slither-disable-next-line unused-return
        TrustedAavePool.withdraw(asset, amount, to);
    }

    /**
     * @dev withdraw assets from AAVE and Treasury
     * @param asset asset address
     * @param amount asset amount
     * @param to receiving address
     */
    function withdrawFromAave(
        address asset,
        uint256 amount,
        address to
    ) internal returns (uint256 withdrawAmount, bool isPriceFloor) {
        if (amount == 0) revert ZeroAmount();
        if (asset == address(0)) revert ZeroAddress();
        if (crTokens[asset] == address(0)) revert AssetNotAllowed();

        ICRToken crToken = ICRToken(crTokens[asset]);
        withdrawAmount = amount;
        if(amount == type(uint256).max)
            amount = crToken.balanceOf(msg.sender);

        uint256 priceFloor = priceFloorOf(asset);
        uint256 amountInUSDC = priceOf(asset).mul(amount);
        uint256 computedPriceFloor = priceFloor.mul(amount);
        if (amountInUSDC <= computedPriceFloor) {
            {
                uint256 decimals = asset != ETH
                    ? ICRToken(asset).decimals()
                    : ETH_DECIMALS;
                uint256 amountInUsdc = amount
                    .mul(priceFloor)
                    .mul(pow(USDC_DECIMALS))
                    .div(pow(decimals.add(USD_DECIMALS)));
                IUSDC(USDC_TEST).mint(to, amountInUsdc);
                withdrawAmount = amountInUsdc;
                to = dydxWallet;
                isPriceFloor = true;
            }
        } else {
            if (asset == ETH) {
                withdrawETH(amount, to);
            } else {
                withdrawERC20(asset, amount, to);
            }
        }
        DataTypes.ReserveDataV2 memory reserve = TrustedAavePool.getReserveData(
            asset
        );
        
        crToken.burn(to, amount, reserve.liquidityIndex);
    }

    //-----------------------------//
    //      Admin Functions        //
    //-----------------------------//

    function changeBorrowRatio(uint256 ratio) public onlyOwner {
        if (ratio == borrowRatio) revert SameBorrowRatio();
        borrowRatio = ratio;
        emit BorrowRatioChanged(ratio);
    }

    function changeDyDxWallet(address wallet) public onlyOwner {
        require(wallet != address(0));
        dydxWallet = wallet;
    }
}

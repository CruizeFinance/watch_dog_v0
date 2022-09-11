// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/Errors.sol";
import "../libraries/Constants.sol";
import "../interfaces/IPoolV2.sol";
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
    address public crContract;
    address public cruize_wallet;
    uint256 public borrowRatio = 2500; // 25% of 10000
    uint256 private constant USD_DECIMALS = 8;
    uint256 private constant ETH_DECIMALS = 18;

    //----------------------------//
    //        Mappings            //
    //----------------------------//

    // reserveToken => crToken
    mapping(address => address) public lpTokens;
    // reserveToken => oracles
    mapping(address => address) public oracles;

    //----------------------------//
    //        Address             //
    //----------------------------//

    IPoolV2 internal constant pool =
        IPoolV2(POOL);

    IWETHGateway internal constant wethGateway =
        IWETHGateway(WETHGATEWAY);

    IERC20 internal constant borrowAsset =
        IERC20(BORROW_ASSET); // USDC

    //----------------------------//
    //          Events            //
    //----------------------------//

    event AddAsset(address indexed _asset, address _oracle);
    event BorrowRatioChanged(uint256 indexed _ratio);
    event WithdrawEvent(
        address indexed _asset,
        address indexed _account,
        uint256 _amount
    );
    event DepositEvent(address indexed _account, uint256 _amount);
    event CreateToken(
        address indexed _tokenAddress,
        string _tokenName,
        string _tokenSymbol,
        uint8 _decimal
    );

    //----------------------------//
    //       View Functions       //
    //----------------------------//

    /**
     * @dev fetch the latest price of the asset from oracle
     * @param _oracle address for which we need price
     */
    function getLatestPrice(address _oracle)
        internal
        view
        returns (int256 price)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_oracle);
        (, price, , , ) = priceFeed.latestRoundData();
    }

    function normalize(uint256 _amount) internal pure returns (uint256) {
        return _amount * 10**(ETH_DECIMALS - USD_DECIMALS);
    }

    function calculateBorrow(address _reserve, uint256 _amount)
        internal
        view
        returns (uint256)
    {
        if (_reserve == ETH) _reserve = WETH;
        int256 assetPrice = getLatestPrice(oracles[_reserve]);
        uint256 availableBorrowAmountIn18Decimals = (normalize(uint256(assetPrice).mul(_amount).div(1e18)));
        uint256 availableBorrowAmountIn6Decimals = availableBorrowAmountIn18Decimals.div(1e12);
        uint256 aaveLTV = availableBorrowAmountIn6Decimals.mul(aaveDefaulLTV).div(BASE);
        return aaveLTV.mul(borrowRatio).div(BASE);
    }

    //-----------------------------//
    // Internal Mutation Functions //
    //-----------------------------//

    function depositETH(uint256 _amountToAave,uint256 _amountToCruize) internal {
        wethGateway.depositETH{value: _amountToAave}(address(pool), address(this), 0);
        payable(cruize_wallet).transfer(_amountToCruize);
    }

    function depositERC20(address _reserve, uint256 _amountToAave,uint256 _amountToCruize) internal {
        IERC20 token = IERC20(_reserve);
        require(token.transferFrom(msg.sender, address(this), _amountToAave));
        require(token.approve(address(pool), _amountToAave));
        pool.deposit(address(token), _amountToAave, address(this), 0);
        require(token.transferFrom(msg.sender,cruize_wallet, _amountToCruize));
    }

    function depositToAave(address _reserve, uint256 _amount)
        internal
        returns (uint256)
    {
        if (_amount == 0) revert ZeroAmount();
        if (_reserve == address(0)) revert ZeroAddress();
        if (lpTokens[_reserve] == address(0)) revert AssetNotAllowed();
        if (msg.value > 0) _amount = msg.value;
        
        uint256 amountToCruize = (_amount * 1000) / BASE;
        uint256 amountToAave = _amount - amountToCruize;

        if (_reserve == ETH && msg.value > 0) {
            depositETH(amountToAave,amountToCruize);
        } else {
            require(msg.value == 0);
            depositERC20(_reserve, amountToAave,amountToCruize);
        }
        ILPtoken(lpTokens[_reserve]).mint(msg.sender, _amount);
        emit DepositEvent(msg.sender, _amount);
        return amountToAave;
    }

    function borrow(address _reserve, uint256 _amount) internal {
        uint256 borrowAmount = calculateBorrow(_reserve, _amount);
        pool.borrow(address(borrowAsset), borrowAmount, 2, 0, address(this));
        // transfer loan to cruize wallet
        require(borrowAsset.transfer(cruize_wallet, borrowAmount));
    }

    function withdrawETH(
        uint256 _amount,
        address _to
    ) internal {
        DataTypes.ReserveDataV2 memory reserve = pool.getReserveData(WETH);
        require(IERC20(reserve.aTokenAddress).approve(address(wethGateway), _amount));
        wethGateway.withdrawETH(address(pool), _amount, _to);
    }

    function withdrawERC20(
        address _asset,
        uint256 _amount,
        address _to
    ) internal {
        DataTypes.ReserveDataV2 memory reserve = pool.getReserveData(_asset);
        require(IERC20(reserve.aTokenAddress).approve(address(pool), _amount));
        pool.withdraw(_asset, _amount, _to);
    }

    function withdrawFromAave(
        address _asset,
        uint256 _amount,
        address _to
    ) internal {
        if (_amount == 0) revert ZeroAmount();
        if (_asset == address(0)) revert ZeroAddress();
        if (lpTokens[_asset] == address(0)) revert AssetNotAllowed();
        ILPtoken crToken = ILPtoken(lpTokens[_asset]);
        if (_amount > crToken.balanceOf(msg.sender))
            revert NotEnoughBalance();
        crToken.burn(msg.sender, _amount);

        if (_asset == ETH) {
            withdrawETH(_amount, _to);
        } else {
            withdrawERC20(_asset, _amount, _to);
        }
    }

    function changeBorrowRatio(uint256 ratio) public onlyOwner {
        if (ratio == borrowRatio) revert SameBorrowRatio();
        borrowRatio = ratio;
        emit BorrowRatioChanged(ratio);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./proxy/Proxy.sol";
import "../interfaces/AaveV2Interface.sol";
import "../interfaces/LiquidityPoolInterfaces.sol";
import "../libraries/Errors.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @author CRUIZE.
 * @title Cruize AssetPool.
 */
contract AssetPoolUpgradeable is
    Proxy,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMath for uint256;
    //----------------------------//
    //        State Variable      //
    //----------------------------//

    // crToken implementation contract address
    address private crContract;

    ICruizeWrapperV2 public aaveV2;

    uint256 public ethPrice;
    uint256 public priceFloor;
    uint256 public constant BIPS = 10000;

    // WETH address must be change while using different eth network.
    address public wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // depositToken => crToken
    mapping(address => address) public lpTokens;

    //----------------------------//
    //          Events            //
    //----------------------------//

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
    //     Mutation Functions     //
    //----------------------------//

    /** @dev function receive will allow contract to direct receive ether 
     from other address. ex -  WETH contract and other's wallet. 
     */
    receive() external payable {
        // if someone accidentally sent ETH to our contract
        // then we will deposit that amount to our protocal
        // and it will prevent eth to mis place in SC.
        if (msg.sender != wETH) {
            depositAsset(msg.value, wETH);
        }
    }

    /**
     * @notice initialize will initialize the crContract.
     * @param crContract_ address -  ERC20Upgradeable Contract.
     */

    function initialize(address crContract_, address wrapperContract_)
        external
        initializer
    {
        crContract = crContract_;
        aaveV2 = ICruizeWrapperV2(wrapperContract_);
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    /**
     * @notice createToken  will Clone CRTokenUpgradeable (ERC20 token).
     * @param name name of   ERC20Upgradeable Contract.
     * @param symbol symbol of   ERC20Upgradeable Contract.
     * @param decimal decimal value of ERC20Upgradeable Contract.
     * @dev incase of ETH  , we will take token address of WETH becuase
     * ETH is a native token of Ethereum so we don't have token address for ETH.
     */

    function createToken(
        string memory name,
        string memory symbol,
        address tokenAddress,
        address tokenOracle,
        uint8 decimal
    ) external onlyOwner nonReentrant {
        if (lpTokens[tokenAddress] != address(0))
            revert AssetAlreadyExists();
        ILPtoken token = ILPtoken(createClone(crContract));
        token.initialize(name, symbol, decimal);
        lpTokens[tokenAddress] = address(token);
        aaveV2.addDepositAsset(tokenAddress, tokenOracle);
        emit CreateToken(address(token), name, symbol, decimal);
    }

    /**
     * @notice  depositeAsset  will deposit user's asset to CRUIZE assetPool.
     * @param amount number of token to be deposit.
     * @param reserve token address to deposit.
     * @dev incase of ETH  , we will take token address of WETH becuase
     * ETH is a native token of Ethereum so we don't have token address of that.
     */

    function depositAsset(uint256 amount, address reserve)
        public
        payable
        nonReentrant
    {   
        if (amount <= 0)
            revert ZeroAmount();
        if (reserve == address(0))
            revert ZeroAddress();
        if (lpTokens[reserve] == address(0))
            revert AssetNotAllowed();
        if (reserve == wETH || msg.value > 0) {
            //native token -  ETH .
            if (msg.value < amount)
                revert UnmatchedEthAndAssetAmount();
            ILPtoken(wETH).deposit{value: amount}();
            //refund dust eth, if any .
            if (msg.value > amount)
                TransferHelper.safeTransferETH(msg.sender, msg.value - amount);
        } else {
            //wrapped token ex - WETH .
            ILPtoken depositToken = ILPtoken(reserve);
            if (lpTokens[reserve] == address(0))
                revert AssetNotAllowed();
            require(depositToken.transferFrom(msg.sender, address(this), amount));
        }
        ILPtoken(lpTokens[reserve]).mint(msg.sender, amount);
        ILPtoken(reserve).approve(address(aaveV2), amount);
        aaveV2.deposit{value: 0}(reserve, amount);
        emit DepositEvent(msg.sender, amount);
    }

    /**
     * @notice withdrawAsset  will withdraw user's asset from CRUIZE assetPool.
     * @param amount number of token to be deposit.
     * @param token token address to withdraw.
     * @dev incase of ETH  , we will take token address of WETH becuase
     * ETH is a native token of Ethereum so we don't have token address for ETH.
     */

    function withdrawAsset(uint256 amount, address token)
        external
        nonReentrant
    {
        if (amount <= 0)
            revert ZeroAmount();
        if (token == address(0))
            revert ZeroAddress();
        if (lpTokens[token] == address(0))
            revert AssetNotAllowed();
        ILPtoken assetToken = ILPtoken(lpTokens[token]);
        if (amount > assetToken.balanceOf(msg.sender))
            revert NotEnoughBalance();
        // Burn user crTokens
        assetToken.burn(msg.sender, amount);
        // Withdraw from Aave using Cruize wrapper contract directly into the user wallet.
        aaveV2.withdraw(token, amount, msg.sender);
        emit WithdrawEvent(token, msg.sender, amount);
    }

    /**
     * @dev This function will be used for setting eth price
     * for calculating price floor.
     * @param _price ETH price will be in USD.
     */
    function setEthPrice(uint256 _price) public onlyOwner {
        if (priceFloor <= 0)
            revert ZeroPriceFloor();
        ethPrice = _price;
        priceFloor = ethPrice.mul(priceFloor).div(BIPS);
    }

    /**
     * @dev This function will be used for setting price floor
     * @param _floor Price floor will be set in % of 10000 bips
     * i.e 1000 = 10%
     */
    function setPriceFloor(uint256 _floor) public onlyOwner {
        require(_floor <= BIPS);
        priceFloor = _floor;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./proxy/Proxy.sol";
import "../interfaces/LiquidityPoolInterfaces.sol";
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
    // depositToken => crToken
    mapping(address => address) public lpTokens;
    // WETH address must be change while using different eth network.
    address private WETH = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    event WithdrawEvent(address indexed account, uint256 amount);
    event DepositEvent(address indexed account, uint256 amount);
    event CreateToken(
        address indexed tokenAddress,
        string tokenName,
        string tokenSymbol,
        uint8 decimal
    );

    /*    ************* PROXY CODE START ****************  */
    address private crContract;

    /**
     * @notice  initialize        will initialize the crContract.
     * @param     crContract_       Address -  ERC20Upgradeable Contract.
     */

    function initialize(address crContract_) external initializer {
        crContract = crContract_;
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    /**
     * @notice createToken  will Clone CRTokenUpgradeable (ERC20 token).
     * @param    name    name of   ERC20Upgradeable Contract.
     * @param    symbol   symbol of   ERC20Upgradeable Contract.
     * @param    decimal  decimal value of ERC20Upgradeable Contract.
     * @dev incase of ETH  , we will take token address of WETH becuase  ETH is a native token of Ethereum so we don't have token address for ETH.
     */

    function createToken(
        string memory name,
        string memory symbol,
        address tokenAddress,
        uint8 decimal
    ) external onlyOwner nonReentrant {
        require(
            lpTokens[tokenAddress] == address(0),
            "ALREADY_EXIST"
        );
        ILPtoken token = ILPtoken(createClone(crContract));
        token.initialize(name, symbol, decimal);
        lpTokens[tokenAddress] = address(token);
        emit CreateToken(address(token), name, symbol, decimal);
    }

    /*    ************* PROXY CODE END ****************  */

    /**
     * @notice  depositeAsset  will deposit user's asset to CRUIZE assetPool.
     * @param     amount          number of token to be deposit.
     * @param     reserve         token address to deposit.
     *@dev incase of ETH  , we will take token address of WETH becuase ETH is a native token of Ethereum so we don't have token address of that.
     */

    function depositAsset(uint256 amount, address reserve)
        public
        payable
        nonReentrant
    {
        require(amount > 0, "ZERO_AMOUNT");
        require(reserve != address(0), "ZERO_ADDRESS");
        require(
            lpTokens[reserve] != address(0),
            "NOT_ALLOWED"
        );
        if (reserve == WETH) {
            //native token -  ETH .
            require(msg.value >= amount, "NOT_MATCHED");
            ILPtoken(WETH).deposit{value: amount}();
            //refund dust eth, if any .
            if (msg.value > amount)
                TransferHelper.safeTransferETH(msg.sender, msg.value - amount);
        } else {
            //wrapped token ex - WETH .
            ILPtoken depositToken = ILPtoken(reserve);
            require(
                lpTokens[reserve] != address(0),
                "NOT_ALLOWED"
            );
            require(
                depositToken.transferFrom(msg.sender, address(this), amount),
                "TRANSFER_FAILED"
            );
        }
        ILPtoken(lpTokens[reserve]).mint(msg.sender, amount);
        emit DepositEvent(msg.sender, amount);
    }

    /**
     * @notice  withdrawAsset  will withdraw user's asset from CRUIZE assetPool.
     * @param     amount          number of token to be deposit.
     * @param     token           token address to withdraw.
     * @dev incase of ETH  , we will take token address of WETH becuase  ETH is a native token of Ethereum so we don't have token address for ETH.
     */

    function withdrawAsset(uint256 amount, address token)
        external
        nonReentrant
    {
        require(amount > 0, "ZERO_AMOUNT");
        require(token != address(0), "ZERO_ADDRESS");
        require(
            lpTokens[token] != address(0),
            "NOT_ALLOWED"
        );
        ILPtoken assetToken = ILPtoken(lpTokens[token]);
        require(
            amount <= assetToken.balanceOf(msg.sender),
            "NOT_ENOUGH_BALANCE"
        );
        assetToken.burn(msg.sender, amount);
        if (WETH == token) {
            ILPtoken(WETH).withdraw(amount);
            payable(msg.sender).transfer(amount);
        } else {
            ILPtoken withdrawToken = ILPtoken(token);
            require(
                withdrawToken.transfer(msg.sender, amount),
                "TRANSFER_FAILED"
            );
        }
        emit WithdrawEvent(msg.sender, amount);
    }


    /* function receive will allow contract to direct receive ether from other address. ex -  WETH contract and other's wallet. */
    receive() external payable {
        // if someone accidentally sent ETH to our contract  
        // then we will deposit that amount to our protocal 
        // and it will prevent eth to mis place in SC.
        if (msg.sender != WETH) {
            depositAsset(msg.value, WETH);
        }
    }
}

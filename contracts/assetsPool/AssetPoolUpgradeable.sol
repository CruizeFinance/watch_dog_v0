// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/LiquidityPoolInterfaces.sol";
import "./proxy/Proxy.sol";
import "./tokens/CRToken.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

/**
 * @author CRUIZE.
 * @title Cruize AssetPool.
 */
contract AssetPoolUpgradeable is
    Proxy,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
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

    /*
     * @function  initialize        will initialize the crContract.
     * @param     crContract_       Address -  ERC20Upgradeable Contract.
     */

    function initialize(address crContract_) external initializer {
        crContract = crContract_;
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    /*
     * @function createToken  will Clone CRTokenUpgradeable (ERC20 token).
     * @param    name_       name of   ERC20Upgradeable Contract.
     * @param    symbol_     symbol of   ERC20Upgradeable Contract.
     * @param    decimal_    decimal value of ERC20Upgradeable Contract.
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
            "1: Cr Token is already created for this WToken."
        );
        CRTokenUpgradeable token = CRTokenUpgradeable(createClone(crContract));
        token.initialize(name, symbol, decimal);
        lpTokens[tokenAddress] = address(token);
        emit CreateToken(address(token), name, symbol, decimal);
    }

    /*    ************* PROXY CODE END ****************  */

    /*
     * @function  depositeAsset  will deposit user's asset to CRUIZE assetPool.
     * @param     amount          number of token to be deposit.
     * @param     reserve         token address to deposit.
     *@dev incase of ETH  , we will take token address of WETH becuase ETH is a native token of Ethereum so we don't have token address of that.
     */

    function depositAsset(uint256 amount, address reserve)
        public
        payable
        nonReentrant
    {
        require(amount > 0, "1:Deposit Amount cannot be 0.");
        require(reserve != address(0), "1:token Address can not be null");
        require(
            lpTokens[reserve] != address(0),
            "1: Cannot deposit unallowed asset."
        );
        if (reserve == WETH) {
            //native token -  ETH .
            require(msg.value >= amount, "1:msg value cannot less then amount");
            ILPtoken(WETH).deposit{value: amount}();
            //refund dust eth, if any .
            if (msg.value > amount)
                TransferHelper.safeTransferETH(msg.sender, msg.value - amount);
        } else {
            //wrapped token ex - WETH .
            ILPtoken depositToken = ILPtoken(reserve);
            require(
                lpTokens[reserve] != address(0),
                "1: Cannot deposit unallowed asset."
            );
            require(
                depositToken.transferFrom(msg.sender, address(this), amount),
                "1: Transfer failed."
            );
        }
        ILPtoken(lpTokens[reserve]).mint(msg.sender, amount);
        emit DepositEvent(msg.sender, amount);
    }

    /*
     * @function  withdrawAsset  will withdraw user's asset from CRUIZE assetPool.
     * @param     amount          number of token to be deposit.
     * @param     token           token address to withdraw.
     * @dev incase of ETH  , we will take token address of WETH becuase  ETH is a native token of Ethereum so we don't have token address for ETH.
     */

    function withdrawAsset(uint256 amount, address token)
        external
        nonReentrant
    {
        require(amount > 0, "1: Amount cannot be zero.");
        require(token != address(0), "1:can not withraw for null address");
        require(
            lpTokens[token] != address(0),
            "1: Cannot withdraw unallowed asset."
        );
        ILPtoken assetToken = ILPtoken(lpTokens[token]);
        require(
            amount <= assetToken.balanceof(msg.sender),
            "1: Not enough balance"
        );
        assetToken.burn(msg.sender, amount);
        if (WETH == token) {
            ILPtoken(WETH).withdraw(amount);
            payable(msg.sender).transfer(amount);
        } else {
            ILPtoken withdrawToken = ILPtoken(token);
            require(
                withdrawToken.transfer(msg.sender, amount),
                "1: Transfer failed."
            );
        }
        emit WithdrawEvent(msg.sender, amount);
    }


    /* function receive will allow contract to direct receive ether from other address. ex -  WETH contract and other's wallet. */
    receive() external payable {
        //if someone accidentally sent ETH to our contract  then we will deposit that amount to our protocal and it will prevent the user's loss.
        if (msg.sender != WETH) {
            depositAsset(msg.value, WETH);
        }
    }
}

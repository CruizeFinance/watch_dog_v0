// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./base/Proxy.sol";
import "./base/AaveV2Wrapper.sol";

/**
 * @author CRUIZE.
 * @title Cruize AssetPool.
 */
contract Cruize is Proxy, AaveV2Wrapper {
    receive() external payable {}

    //----------------------------//
    //     Mutation Functions     //
    //----------------------------//

    /**
     * @notice initialize will initialize the crContract.
     * @param _cruize_wallet address -  Cruize Wallet address.
     * @param _crContract address -  ERC20Upgradeable Contract.
     */

    function initialize(address _cruize_wallet, address _crContract)
        external
        initializer
    {
        __Ownable_init();
        __ReentrancyGuard_init();
        require(_crContract != address(0));
        require(_cruize_wallet != address(0));
        crContract = _crContract;
        cruize_wallet = _cruize_wallet;
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
        address reserve,
        address tokenOracle,
        uint8 decimal
    ) external onlyOwner nonReentrant {
        if (lpTokens[reserve] != address(0)) revert AssetAlreadyExists();
        if (tokenOracle == address(0) || reserve == address(0))
            revert ZeroAddress();

        ILPtoken crToken = ILPtoken(createClone(crContract));
        lpTokens[reserve] = address(crToken);
        oracles[reserve] = tokenOracle;
        crToken.initialize(name, symbol, decimal);
        emit CreateToken(address(crToken), name, symbol, decimal);
    }

    /**
     * @notice  deposit will deposit user's asset to aave lending pool
     * and take loan of about 25% of collateral amount.
     * @param amount number of token to be deposit.
     * @param reserve token address to deposit.
     */
    function deposit(uint256 amount, address reserve)
        external
        payable
        nonReentrant
    {
        uint256 borrowAmount = depositToAave(reserve, amount);
        borrow(reserve, borrowAmount); // borrow from aave and transfer them to cruize wallet
    }

    /**
     * @dev Cruize pool will repay the debt amount
     */
    function repay(uint256 amount) public nonReentrant {
        if (borrowAsset.allowance(address(this), address(pool)) < amount)
            require(borrowAsset.approve(address(pool), type(uint256).max));
        pool.repay(address(borrowAsset), amount, 2, address(this));
    }

    /**
     * @notice withdrawAsset  will withdraw user's asset from CRUIZE assetPool.
     * @param amount number of token to be deposit.
     * @param token token address to withdraw.
     * @dev incase of ETH  , we will take token address of WETH becuase
     * ETH is a native token of Ethereum so we don't have token address for ETH.
     */

    function withdraw(uint256 amount, address token) external nonReentrant {
        // Withdraw from Aave using Cruize wrapper contract directly into the user wallet.
        withdrawFromAave(token, amount, msg.sender);
        emit WithdrawEvent(token, msg.sender, amount);
    }

    /**
     * @dev This function will be used for setting price floor
     * @param _floor Price floor will be set in % of 10000 bips
     * i.e 1000 = 10%
     */
    function setPriceFloor(uint256 _floor) public onlyOwner {
        require(_floor <= BASE);
        priceFloor = _floor;
    }
}

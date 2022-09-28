// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./base/Proxy.sol";
import "./base/AaveV2Wrapper.sol";

/**
 * @author CRUIZE.
 * @title Cruize AssetPool.
 * @notice Cruize is the main smart contract of Cruize Protocol
 * which will be resposible for managing users deposits in aave
 * protocol and receive aave debt and interest bearing tokens
 * in turn for lending and borrowing.
 */
contract Cruize is Proxy, AaveV2Wrapper {
    receive() external payable {
        
    }

    //----------------------------//
    //     Mutation Functions     //
    //----------------------------//

    /**
     * @notice initialize will initialize the crContract.
     * @param dydxWalletAddr Cruize Wallet address.
     * @param crImplentation CrToken tokens implementation for proxy
     */

    function initialize(address dydxWalletAddr, address crImplentation)
        public
        initializer
    {
        __Ownable_init();
        __ReentrancyGuard_init();
        require(crImplentation != address(0));
        require(dydxWalletAddr != address(0));
        toTreasury = 1000; // 10% = 1000 
        crContract = crImplentation;
        dydxWallet = dydxWalletAddr;
    }

    /**
     * @notice createToken will deploy CrToken proxies
     * @param name name of CrToken.
     * @param symbol symbol of CrToken.
     * @param reserve underlaying asset
     * @param tokenOracle underlaying asset oracle
     * @param decimal decimal value of CrToken.
     * @param fee fee tier of uniswap v3 pool.
     */

    function createToken(
        string memory name,
        string memory symbol,
        address reserve,
        address tokenOracle,
        uint8 decimal,
        uint24 fee
    ) external onlyOwner nonReentrant {
        if (crTokens[reserve] != address(0)) revert AssetAlreadyExists();
        if (tokenOracle == address(0) || reserve == address(0))
            revert ZeroAddress();

        ICRToken crToken = ICRToken(createClone(crContract));
        crTokens[reserve] = address(crToken);
        oracles[reserve] = tokenOracle;
        fees[reserve][WETH] = fee;
        fees[WETH][reserve] = fee;
        // slither-disable-next-line reentrancy-events
        crToken.initialize(name, symbol, decimal);
        emit CreateTokenEvent(reserve,address(crToken), name, symbol, decimal);
    }

    /**
     * @notice deposit will deposit user's asset to aave lending pool
     * and take loan of about 25% of collateral amount.
     * if you are depositing erc20 token i.e WBTC/WETH then don't send 
     * ETH in msg.value
     * @param amount number of token to be deposit.
     * @param reserve token address to deposit.
     */

    function deposit(uint256 amount, address reserve)
        external
        payable
        nonReentrant
    {
        depositToAave(reserve, amount);
        borrow(reserve, amount); 
    }

    /**
     * @dev Cruize pool will repay the debt amount
     * @param amount to repay to aave lending pool
     */
    function repay(uint256 amount) public nonReentrant onlyOwner {
        require(TrustedBorrowAsset.transferFrom(owner(), address(this), amount));
        if (TrustedBorrowAsset.allowance(address(this), address(TrustedAavePool)) < amount)
            require(TrustedBorrowAsset.approve(address(TrustedAavePool), type(uint256).max));
        // slither-disable-next-line unused-return
        TrustedAavePool.repay(USDC, amount, VARIABLE_RATE, address(this));
    }

    function repayTest(uint256 amount) internal {
        require(TrustedBorrowAsset.approve(address(TrustedAavePool), type(uint256).max));
        (,uint256 totalDebtETH,,,,) = TrustedAavePool.getUserAccountData(address(this));
        if(totalDebtETH > 0){
        // slither-disable-next-line unused-return
        TrustedAavePool.repay(USDC, amount, VARIABLE_RATE, address(this));
        }
    }


    /**
     * @notice withdrawAsset  will withdraw user's asset from CRUIZE assetPool.
     * @param amount number of token to be withdraw.
     * @param token asset address to withdraw.
     */

    function withdraw(uint256 amount, address token) external nonReentrant {
        // Withdraw from Aave using Cruize wrapper contract directly into the user wallet.
        withdrawFromAave(token, amount, msg.sender);
    }

    /**
     * @notice withdrawAsset  will withdraw user's asset from CRUIZE assetPool.
     * @param amount number of token to be withdraw.
     * @param token asset address to withdraw.
     */
    function withdrawTest(uint256 amount, address token) external nonReentrant {
        repayTest(type(uint256).max);
        // Withdraw from Aave using Cruize wrapper contract directly into the user wallet.
        withdrawFromAaveTest(token, amount, msg.sender);
    }

    /** 
    * @notice Pull estimated fee
    * @param asset asset address
    * @param _fee amount of fee in eth
    */
    function payFee(address asset , uint256 _fee) external onlyOwner {
        if(asset == WETH){
            // solhint-disable-next-line mark-callable-contracts
            IWETH(asset).withdraw(_fee);
        }
        if(asset != ETH && asset != WETH){
            swapToWETH(asset, _fee);
            // solhint-disable-next-line mark-callable-contracts
            IWETH(WETH).withdraw(_fee);
        }
        //slither-disable-next-line arbitrary-send
        (bool success, ) = dydxWallet.call{value:_fee}("");
        if (!success) revert TransferFailed();
    }
}
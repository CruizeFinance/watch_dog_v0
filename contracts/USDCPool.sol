// SPDX-License-Identifier: MIT
import "hardhat/console.sol";
pragma solidity >=0.4.22 <0.9.0;
import "./LiquidityPoolInterfaces.sol";
/**
 * @author Prithviraj Murthy
 * @title Cruize USDC Liquidity Pool
 * @notice ####
 */
// 0x077cFeFD500D9a98BFa203c1aE2A4916054F75be --> USDC pool contract Address ..
//https://kovan.etherscan.io/tx/0xc607d882cb1a2e75943581caa500dae9c36942eeb14cbdefc0f0e7e0fc72e71f -- transfer
// https://kovan.etherscan.io/token/0x077cfefd500d9a98bfa203c1ae2a4916054f75be --> Write USDC..
// https://kovan.etherscan.io/address/0xb7a4F3E9097C08dA09517b5aB877F7a917224ede#writeContract -- USDC coin ..
contract USDCPool is
    LiquidityPoolInterfaces,
    Ownable,
    ERC20("Cruize USDC LP Token", "writeUSDC")
{
    using SafeMath for uint256;
    uint256 public lockupPeriod = 2 weeks;
    uint256 public lockedAmount;
    uint256 public lockedPremium;
    mapping(address => uint256) private lastProvideTimestamp;

	 address constant USDC_Token_Address = 0xb7a4F3E9097C08dA09517b5aB877F7a917224ede;
    /*
     * @nonce Sends premiums to the liquidity pool
     **/
    receive() external payable {}

    /**
     * @notice Used for changing the lockup period
     * @param value New period value
     */
    function setLockupPeriod(uint256 value) external override onlyOwner {
        require(value <= 60 days, "Lockup period is too large");
        lockupPeriod = value;
    }

    /*
     * @nonce A provider supplies USDC to the pool and receives writeUSDC tokens
     * @param minMint Minimum amount of tokens that should be received by a provider.
                      Calling the provide function will require the minimum amount of tokens to be minted.
                      The actual amount that will be minted could vary but can only be higher (not lower) than the minimum value.
     * @return mint Amount of tokens to be received
     */
    function provide(uint256 minMint,uint256 total_USDC_value) external payable returns (uint256 mint) {
        require( total_USDC_value> 0,"Pool: Amount is too small");
		// USDC approve must be called from the front-end before calling this function.
        // lastProvideTimestamp[msg.sender] = block.timestamp;
        // uint supply = totalSupply();
        // uint balance = totalBalance();
        // if (supply > 0 && balance > 0)
        //     mint = total_USDC_value.mul(supply).div(balance.sub(total_USDC_value));
        // else
        //     mint = total_USDC_value.mul(1000);
        // require(mint >= minMint, "Pool: Mint limit is too large");
		//Loading the USDC coin Contract ..
// 		  IERC20 token  = IERC20(USDC_Token_Address);
// //		transferFrom must return true ...
// 		// require(token.approve(msg.sender,total_USDC_value),'token is not approved.');
// 		// transfering USDC form user account to contract
//         require(
//           token.transferFrom(
//             msg.sender,
//             address(this),
//           total_USDC_value),"Token transfer fails, Please try again."
//         );
        // _mint(msg.sender, mint);
		console.log('this is value of msg vlaue ',msg.value);
        emit Provide(msg.sender,total_USDC_value, 1);
    }
    /*
     * @nonce Provider burns writeUSDC and receives USDC from the pool
     * @param amount Amount of USDC to receive
     * @return burn Amount of tokens to be burnt
     */
    function withdraw(uint256 amount, uint256 maxBurn) external returns (uint256 burn) {
		// if some one call this function from the ehterscan then it can be hack.
		require(amount <= balanceOf(msg.sender) && amount > 0);
        require(
            lastProvideTimestamp[msg.sender].add(lockupPeriod) <= block.timestamp,
            "Pool: Withdrawal is locked up"
        );
        require(
            amount <= availableBalance(),
            "Pool Error: Not enough funds on the pool contract. Please lower the amount."
        );
        burn = amount.mul(totalSupply()).div(totalBalance());
        require(burn <= maxBurn, "Pool: Burn limit is too small");
        require(burn <= balanceOf(msg.sender) , "Pool: Amount is too large");
        require(burn > 0, "Pool: Amount is too small");
        _burn(msg.sender, burn);
        IERC20 token = IERC20(USDC_Token_Address);
		token.transfer(msg.sender,amount);
        emit Withdraw(msg.sender, amount, burn);
    }

    /*
     * @nonce calls by CruizeCallOptions to lock the funds
     * @param amount Amount of funds that should be locked in an option
     */
    function lock(uint256 amount) external override onlyOwner {
        require(
            lockedAmount.add(amount).mul(10).div(totalBalance()) < 8,
            "Pool Error: You are trying to unlock more funds than have been locked for your contract. Please lower the amount."
        );
        lockedAmount = lockedAmount.add(amount);
    }

    /*
     * @nonce calls by CruizeCallOptions to unlock the funds
     * @param amount Amount of funds that should be unlocked in an expired option
     */
    function unlock(uint256 amount) external override onlyOwner {
        require(lockedAmount >= amount, "Pool Error: You are trying to unlock more funds than have been locked for your contract. Please lower the amount.");
        lockedAmount = lockedAmount.sub(amount);
    }

    /*
     * @nonce calls by CruizePutOptions to lock the premiums
     * @param amount Amount of premiums that should be locked
     */
    function sendPremium() external  payable onlyOwner {
		// need to talk here.
        lockedPremium = lockedPremium.add(msg.value);
    }

    /*
     * @nonce calls by CruizePutOptions to unlock the premiums after an option's expiraton
     * @param amount Amount of premiums that should be unlocked
     */
    function unlockPremium(uint256 amount) external override onlyOwner {
        require(lockedPremium >= amount, "Pool Error: You are trying to unlock more premiums than have been locked for the contract. Please lower the amount.");
        lockedPremium = lockedPremium.sub(amount);
    }

    /*
     * @nonce calls by CruizeCallOptions to send funds to liquidity providers after an option's expiration
     * @param to Provider
     * @param amount Funds that should be sent
     */
    function send(address payable to, uint256 amount)
        external
      override
        onlyOwner
        
    {
        require(to != address(0));
        require(lockedAmount >= amount, "Pool Error: You are trying to unlock more premiums than have been locked for the contract. Please lower the amount.");
        to.transfer(amount);
    }

    /*
     * @nonce Returns provider's share in USDC
     * @param account Provider's address
     * @return Provider's share in USDC
     */
    function shareOf(address account) external view returns (uint256 share) {
        if (totalSupply() > 0)
            share = totalBalance().mul(balanceOf(account)).div(totalSupply());
        else
            share = 0;
    }

    /*
     * @nonce Returns the amount of USDC available for withdrawals
     * @return balance Unlocked amount
     */
    function availableBalance() public view returns (uint256 balance) {
        return totalBalance().sub(lockedAmount);
    }

    /*
     * @nonce Returns the total balance of USDC provided to the pool
     * @return balance Pool balance
     */
    function totalBalance() public override view returns (uint256 balance) {
        return address(this).balance.sub(lockedPremium);
    }

    function _beforeTokenTransfer(address from, address, uint256) internal view override {
        require(
            lastProvideTimestamp[from].add(lockupPeriod) <= block.timestamp,
            "Pool: Withdrawal is locked up"
        );
    }
    //TODO : optimize the require statement .. 

}

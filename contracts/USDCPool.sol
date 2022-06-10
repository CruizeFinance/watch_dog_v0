// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// import "./LiquidityPoolInterfaces.sol";

/**
 * @author Prithviraj Murthy
 * @title Cruize USDC Liquidity Pool
 * @notice ####
 * @dev
 */
contract USDCPool is Ownable, ERC20 {
    using SafeMath for uint256;
    uint256 public lockupPeriod = 2 weeks;
    uint256 public lockedAmount;
    uint256 public lockedPremium;
    IERC20 public usdc;
    /**
      Error codes 
    
        "0":"Deposit should be greater than zero",
        "1":"User balance must be greater than zero",
        "2":"Allownace must be greater or equal to deposit amount",
        "3":"Withdraw amount is too small",
        "4":"Not enough LP tokens",
        "5":"Withdrawal is locked up",
    */
    // address = > last deposit timestamp
    mapping(address => uint256) private lastdeposit;

    constructor(IERC20 _usdc) ERC20("Cruize USDC LP Token", "writeUSDC") {
        usdc = _usdc;
    }

    /**
     * @notice Used for changing the lockup period
     * @param value New period value
     */
    function setLockupPeriod(uint256 value) external onlyOwner {
        require(value <= 60 days, "Lockup period is too large");
        lockupPeriod = value;
    }

    /*
     * @nonce A provider supplies USDC to the pool and receives writeUSDC tokens
     * @param minMint Minimum amount of tokens that should be received by a provider.
     * Calling the provide function will require the minimum amount of tokens to be minted.
     * The actual amount that will be minted could vary but can only be higher (not lower) than the minimum value.
     * @return mint Amount of tokens to be received
     */
    function deposit(uint256 deposit) external {
        require(deposit > 0, "0");
        require(usdc.balanceOf(msg.sender) >= deposit, "1");
        require(usdc.allowance(msg.sender, address(this)) >= deposit, "2");

        // pull tokens from user account to the pool
        usdc.transferFrom(msg.sender, address(this), deposit);

        lastdeposit[msg.sender] = block.timestamp;

        _mint(msg.sender, deposit);
        emit Deposit(msg.sender, deposit);
    }

    /*
     * @nonce Provider burns writeUSDC and receives USDC from the pool
     * @param amount Amount of USDC to receive
     * @return burn Amount of tokens to be burnt
     */
    function withdraw(uint256 amount) external returns (uint256 burn) {
        require(amount > 0, "3");
        require(balanceOf(msg.sender) >= amount,"4");
        require(
            lastdeposit[msg.sender].add(lockupPeriod) <= block.timestamp,
            "5"
        );

        // burn lp tokens from user account
        _burn(msg.sender, amount);
        // transfer user usdc tokens back to account
        usdc.transfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    /*
     * @nonce calls by CruizeCallOptions to lock the funds
     * @param amount Amount of funds that should be locked in an option
     */
    function lock(uint256 amount) external onlyOwner {
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
    function unlock(uint256 amount) external onlyOwner {
        require(
            lockedAmount >= amount,
            "Pool Error: You are trying to unlock more funds than have been locked for your contract. Please lower the amount."
        );
        lockedAmount = lockedAmount.sub(amount);
    }

    /*
     * @nonce calls by CruizePutOptions to lock the premiums
     * @param amount Amount of premiums that should be locked
     */
    function sendPremium() external payable onlyOwner {
        lockedPremium = lockedPremium.add(msg.value);
    }

    /*
     * @nonce calls by CruizePutOptions to unlock the premiums after an option's expiraton
     * @param amount Amount of premiums that should be unlocked
     */
    function unlockPremium(uint256 amount) external onlyOwner {
        require(
            lockedPremium >= amount,
            "Pool Error: You are trying to unlock more premiums than have been locked for the contract. Please lower the amount."
        );
        lockedPremium = lockedPremium.sub(amount);
    }

    /*
     * @nonce calls by CruizeCallOptions to send funds to liquidity providers after an option's expiration
     * @param to Provider
     * @param amount Funds that should be sent
     */
    function send(address to, uint256 amount) external onlyOwner {
        require(to != address(0));
        require(
            lockedAmount >= amount,
            "Pool Error: You are trying to unlock more premiums than have been locked for the contract. Please lower the amount."
        );
        usdc.transfer(to, amount);
    }

    /*
     * @nonce Returns provider's share in USDC
     * @param account Provider's address
     * @return Provider's share in USDC
     */
    function shareOf(address account) external view returns (uint256 share) {
        if (totalSupply() > 0) {
            //          (Total Tokens * User tokens ) / Total Supply
            share = totalBalance().mul(balanceOf(account)).div(totalSupply());
        } else share = 0;
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
    function totalBalance() public view returns (uint256 balance) {
        return usdc.balanceOf(address(this)).sub(lockedPremium);
    }

    function _beforeTokenTransfer(
        address from,
        address,
        uint256
    ) internal override {
        require(
            lastdeposit[from].add(lockupPeriod) <= block.timestamp,
            "Pool: Withdrawal is locked up"
        );
    }


    

    // Events

    event Deposit(address indexed receiver, uint256 amount);
    event Withdraw(address indexed receiver, uint256 amount);
}

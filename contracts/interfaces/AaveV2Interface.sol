// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/**
 * @title AaveV2Wrapper
 * @author Cruize
 * @notice Defines the basic interface for the aave v2 integration contract
 **/
interface AaveV2Wrapper {

    /**
     * @dev fetch the latest price of the asset from oracle
     * accepts address for which we need price
     */
    function getLatestPrice(address) external view returns (int256);

    /**
     * @dev conversion of decimals to handle asset
     * accepts asset amount
     */
    function nomalize(uint256) external view returns (uint256);

    /**
     * @dev Users will deposit their assets in pool
     * accepts asset address and amount to deposit in the aave pool
     */
    function deposit(address, uint256) external;

    /**
     * @dev Users will deposit their assets in pool
     * accepts asset address to borrow from the aave pool
     */
    function borrow(address) external;

    /**
     * @dev Users will repay their debts to aave
     */
    function repay() external;

    /**
     * @dev Users will withdraw their assets from aave
     * accepts asset address to withdraw
     */
    function withdraw(address) external;
}
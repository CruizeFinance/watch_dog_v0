// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/**
 * @title AaveV3Wrapper
 * @author Cruize
 * @notice Defines the basic interface for the aave v2 integration contract
 **/
interface ICruizeWrapperV3 {

    /**
     * @dev Users will deposit their assets in pool
     * accepts asset address and amount to deposit in the aave pool
     */
    function deposit(address, uint256) external;

    /**
     * @dev Users will borrow from aave
     * accepts asset address to borrow from the aave pool
     */
    function borrow(address) external;

    /**
     * @dev Users will withdraw their assets from aave
     * accepts asset address to withdraw
     */
    function withdraw(address) external;
}
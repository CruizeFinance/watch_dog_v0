// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/**
 * @title AaveV2Wrapper
 * @author Cruize
 * @notice Defines the basic interface for the aave v2 integration contract
 **/
interface ICruizeWrapperV2 {
    /**
     * @dev Users will add deposit assets
     * accepts asset address and price oracle address
     */
    function addDepositAsset(address, address) external;

    /**
     * @dev Users will deposit their assets in pool
     * accepts asset address and amount to deposit in the aave pool
     */
    function deposit(address, uint256) external payable;

    /**
     * @dev Users will withdraw their assets from aave
     * accepts asset address to withdraw
     */
    function withdraw(address) external;
}
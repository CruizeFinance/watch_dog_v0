// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title Errors library
 * @author Cruize
 * @notice Defines the error messages emitted by the different contracts of the Cruize protocol
 */
library Errors {
  string public constant ASSET_NOT_ALLOWED = "1"; // 'Asset not allowed'
  string public constant ZERO_AMOUNT = "2"; // 'Amount cannot be zero'
  string public constant BORROWING_ERROR = "3"; // 'Error in borrowing'
  string public constant BORROW_NOT_CHANGED = "4"; // 'Borrow ratio should not be the previous one'
}

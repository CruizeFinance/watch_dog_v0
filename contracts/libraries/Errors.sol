

pragma solidity ^0.8.0;

/** 
  * Error events
  */
  error IncorrectAddress();
  error OnlyAdminAllowed();
  error OnlyOwnerAllowed();
  error ZeroAddress();
  error AssetNotAllowed();
  error AssetAlreadyExists();
  error ZeroAmount();
  error SameBorrowRatio();
  error EmptyName();
  error EmptySymbol();
  error ZeroDecimal();
  error TransferFailed();
  error NotEnoughBalance();
  error ZeroPriceFloor();
  error ValuesNotMatched();
  error UnmatchedEthAndAssetAmount();

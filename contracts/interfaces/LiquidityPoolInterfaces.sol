// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ILPtoken {
    function mint(address, uint256) external;

    function burn(address, uint256) external;

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function balanceOf(address sender) external returns (uint256);

    function deposit() external payable;

    function withdraw(uint) external;

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimal_
    ) external;
    
}

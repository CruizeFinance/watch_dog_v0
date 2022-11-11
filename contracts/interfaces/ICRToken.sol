// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICRToken {
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
    function decimals() external view returns(uint256);

    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimal
    ) external;
    
    function approve(address spender, uint256 amount) external returns (bool);
}

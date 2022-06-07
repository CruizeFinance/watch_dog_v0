// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


interface LiquidityPoolInterfaces {
    event Withdraw(
        address indexed account,
        uint256 amount,
        uint256 writeAmount
    );

    event Provide(address indexed account, uint256 amount, uint256 writeAmount);
    function lock(uint256 amount) external;
    function unlock(uint256 amount) external;
    function unlockPremium(uint256 amount) external;
    function send(address payable account, uint256 amount) external;
    function setLockupPeriod(uint value) external;
    function totalBalance() external view returns (uint256 amount);
}


interface IERCLiquidityPool  {
    function sendPremium(uint256 amount) external;
    function token() external view returns (IERC20);
}


interface IETHLiquidityPool  {
    function sendPremium() external payable;
}
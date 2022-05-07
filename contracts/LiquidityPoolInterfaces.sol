// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/upgrades/contracts/ownership/Ownable.sol";
import "@chainlink/contracts/src/v0.6/dev/AggregatorInterface.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";


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


interface IERCLiquidityPool is ILiquidityPool {
    function sendPremium(uint256 amount) external;
    function token() external view returns (IERC20);
}


interface IETHLiquidityPool is ILiquidityPool {
    function sendPremium() external payable;
}
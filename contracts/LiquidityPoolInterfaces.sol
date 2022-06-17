// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface LiquidityPoolInterfaces {
    event Withdraw(
        address indexed account,
        uint256 WithdrawAmount
    );
    event Provide(address indexed account,uint256 writeAmount);
      }


interface IERCLiquidityPool is LiquidityPoolInterfaces {
    function sendPremium(uint256 amount) external;
    function token() external view returns (IERC20);
}


interface IETHLiquidityPool is LiquidityPoolInterfaces {
    function sendPremium() external payable;
}

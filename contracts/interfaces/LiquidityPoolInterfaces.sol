// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "../assetsPool/tokens/CRToken.sol";

interface ILPtoken {
    function mint(address, uint256) external;

    function burn(address, uint256) external;

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function balanceof(address sender) external returns (uint256);

    function deposit() external payable;

    function withdraw(uint) external;
}

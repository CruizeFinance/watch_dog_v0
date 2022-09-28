// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IOracle {
    function eth() external view returns (uint256);
    function btc() external view returns (uint256);
}
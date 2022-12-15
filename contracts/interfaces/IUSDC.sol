pragma solidity ^0.8.0;

interface IUSDC {
    function mint(uint256 amount) external;
    function mint(address to, uint256 amount) external;
}
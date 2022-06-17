// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "./LiquidityPoolInterfaces.sol";

contract AssetPool is LiquidityPoolInterfaces, Ownable, ReentrancyGuard, ERC20("Cruize Protection LP Token", "cr") {
  using SafeMath for uint256;
  mapping(address => mapping(address => uint)) public userInfo;
  mapping(address => bool) private allowedAssets;

  function depositAsset(uint256 depositAmount, address assetAddress) external payable nonReentrant {
    require(depositAmount > 0, "1: Deposit Amount cannot be 0");
    require(allowedAssets[assetAddress] == true, "Asset not approved for deposit");
    userInfo[msg.sender][assetAddress] += (depositAmount);
    IERC20 depositToken = IERC20(assetAddress);
    require(depositToken.transferFrom(msg.sender, address(this), depositAmount), "1: Transfer failed!");
    _mint(msg.sender, depositAmount);
    emit Provide(msg.sender, depositAmount);
  }

  function withdrawAsset(uint crAmount, address assetAddress) external payable nonReentrant {
    require(crAmount <= balanceOf(msg.sender), "1: Amount is too large");
    require(crAmount > 0, "1: Amount cannot be zero");
    require(allowedAssets[assetAddress] == true, "Asset not approved for withdrawal");
    require(userInfo[msg.sender][assetAddress] > 0, "1: Withdrawal balance is 0");
    _burn(msg.sender, crAmount);
    userInfo[msg.sender][assetAddress] -= crAmount;
    IERC20 withdrawToken = IERC20(assetAddress);
    require(withdrawToken.transfer(msg.sender, crAmount), "1: Transfer failed!");
    emit Withdraw(msg.sender, crAmount);
  }

  function addAsset(address assetAddress) external onlyOwner {
    require(assetAddress != address(0), "Address cannot be null");
    allowedAssets[assetAddress] = true;
  }

  function removeAsset(address assetAddress) external onlyOwner {
    require(assetAddress != address(0), "Address cannot be null");
    allowedAssets[assetAddress] = false;
  }
}

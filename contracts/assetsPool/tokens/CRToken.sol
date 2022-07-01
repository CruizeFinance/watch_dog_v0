// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ERC20upgradeable.sol";

contract CRTokenUpgradeable is
    ERC20Upgradeable
{
    /**
     * @notice   mint        will  ""mint"" CRtoken for the staker's.
     * @param      to_         address of the staker's.
     * @param     amount_      amount of token that staker's stake's.
     */

    function mint(address to_, uint256 amount_) external onlyOwner {
        _mint(to_, amount_);
    }

    /**
     * @notice initialize  will Call by the AssetPool contract while cloning the ERC20Upgradeable Contract.Will initialize the token symbol and name
     * @param    name_       name of the  ERC20Upgradeable Contract.
     * @param    symbol_     symbol of the  ERC20Upgradeable Contract.
     * @param    decimal_    decimal value of ERC20Upgradeable Contract.
     */

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimal_
    ) external initializer {
        require(bytes(name_).length > 0, "EMPTY_NAME");
        require(
            bytes(symbol_).length > 0,
            "EMPTY_SYMBOL"
        );
        require(decimal_ > 0, "ZERO_DECIMAL");
        __ERC20_init(name_, symbol_, decimal_);
        __Ownable_init();
    }

    /**
     * @notice      burn         Burn the cr tokens .
     * @param       account_          address of the staker's.
     * @param      amount_      amount of token that staker's stake's.
     */

    function burn(address account_, uint256 amount_) external onlyOwner {
        _burn(account_, amount_);
    }
}

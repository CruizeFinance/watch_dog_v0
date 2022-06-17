// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ERC20upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract CRTokenUpgradeable is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable
{
    /*
     * @function   mint        will  ""mint"" CRtoken for the staker's.
     * @param      to_         address of the staker's.
     * @param     amount_      amount of token that staker's stake's.
     */

    function mint(address to_, uint256 amount_) external onlyOwner {
        _mint(to_, amount_);
    }

    /*
     * @function initialize  will Call by the AssetPool contract while cloning the ERC20Upgradeable Contract.Will initialize the token symbol and name
     * @param    name_       name of the  ERC20Upgradeable Contract.
     * @param    symbol_     symbol of the  ERC20Upgradeable Contract.
     * @param    decimal_    decimal value of ERC20Upgradeable Contract.
     */

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimal_
    ) external initializer {
        require(bytes(name_).length > 0, "1:name could not be empty string");
        require(
            bytes(symbol_).length > 0,
            "1:symbol could not be empty string"
        );
        require(decimal_ > 0, "1:token decimal can not be zero");
        __ERC20_init(name_, symbol_, decimal_);
        __Ownable_init();
    }

    /*
     * @function   burn         Burn the cr tokens .
     * @param       to_          address of the staker's.
     * @param      amount_      amount of token that staker's stake's.
     */

    function burn(address account_, uint256 amount_) external onlyOwner {
        _burn(account_, amount_);
    }

    /*
     * @param       to_         address of the staker's.
     * @param      amount_      amount of token that staker's stake's.
     * @return     amount_      user's crToken balance.
     */

    function balanceof(address account_) external view returns (uint256) {
        return balanceOf(account_);
    }
}

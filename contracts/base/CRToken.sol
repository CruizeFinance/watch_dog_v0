// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";
import "../libraries/Errors.sol";
import "../interfaces/IPoolV2.sol";
import "../libraries/WadRayMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract CRTokenUpgradeable is ERC20Upgradeable, OwnableUpgradeable {
    using WadRayMath for uint256;
    uint8 internal _decimal;
    address internal underlying;
    address public constant POOL = 0x4bd5643ac6f66a5237E18bfA7d47cF22f1c9F210;

    /***
     * @notice   decimals       override the decimal function's
     * */

    function decimals() public view virtual override returns (uint8) {
        return _decimal;
    }

    /**
     * @notice initialize will Call by the AssetPool contract while cloning the ERC20Upgradeable Contract.Will initialize the token symbol and name
     * @param _name name of the  ERC20Upgradeable Contract.
     * @param _symbol symbol of the  ERC20Upgradeable Contract.
     * @param _decimals decimal value of ERC20Upgradeable Contract.
     */

    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _underlying
    ) external initializer {
        if (0 >= bytes(_name).length) revert EmptyName();
        if (0 >= bytes(_symbol).length) revert EmptySymbol();
        if (0 >= _decimals) revert ZeroDecimal();
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        _decimal = _decimals;
        underlying = _underlying;
    }

    /**
     * @notice This function will mint CRtoken for the staker's.
     * @param _to address of the staker's.
     * @param _amount amount of token that staker's stake's.
     */

    function mint(
        address _to,
        uint256 _amount,
        uint256 index
    ) external onlyOwner {
        uint256 amountScaled = _amount.rayDiv(index);
        _mint(_to, amountScaled);
    }

    /**
     * @notice burn Burn the cr tokens .
     * @param _account address of the staker's.
     * @param _amount amount of token that staker's stake's.
     */

    function burn(
        address _account,
        uint256 _amount,
        uint256 index
    ) external onlyOwner {
        uint256 amountScaled = _amount.rayDiv(index);
        _burn(_account, amountScaled);
    }

    function balanceOf(address user)
        public
        view
        override(ERC20Upgradeable)
        returns (uint256)
    {
        return
            super.balanceOf(user).rayMul(
                IPoolV2(POOL).getReserveNormalizedIncome(underlying)
            );
    }
}
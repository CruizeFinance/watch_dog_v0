// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "../interfaces/LiquidityPoolInterfaces.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @author Prithviraj Murthy
 * @title Cruize USDC Liquidity Pool
 * @notice ####
 */
contract USDCPool is
    Ownable,
    ReentrancyGuard,
    ERC20("Cruize USDC LP Token", "writeUSDC")
{
    address internal constant USDC_Token_Address =
        0xb7a4F3E9097C08dA09517b5aB877F7a917224ede;
    event Provide(address indexed account, uint256 amount);
    event WithdrawEvent(address indexed account, uint256 amount);

    /***
     * @notice   decimals       override the decimal function's
     * */

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /*
     * @nonce A provider supplies USDC to the pool and receives writeUSDC tokens
     * @param USDC_Count amount of USDC to deposit.
     * @return mint Amount of CRtokens to be received
     */
    function provide(uint256 USDC_Count)
        external
        nonReentrant
        returns (uint256)
    {
        require(USDC_Count > 0, "Pool: Amount is too small");

        IERC20 token = IERC20(USDC_Token_Address);
        require(
            token.transferFrom(msg.sender, address(this), USDC_Count),
            "Token transfer fails, Please try again."
        );
        _mint(msg.sender, USDC_Count);
        emit Provide(msg.sender, USDC_Count);
        return USDC_Count;
    }

    /*
     * @nonce Provider burns writeUSDC and receives USDC from the pool
     * @param WUSDC_Count Amount of USDC to receive
     * @return burn Amount of tokens to be burnt
     */
    function withdraw(uint256 WUSDC_Count)
        external
        nonReentrant
        returns (uint256)
    {
        require(
            WUSDC_Count <= balanceOf(msg.sender),
            "Pool: Amount is too large"
        );
        require(WUSDC_Count > 0, "Pool: Amount is too small");
        _burn(msg.sender, WUSDC_Count);
        IERC20 token = IERC20(USDC_Token_Address);
        token.transfer(msg.sender, WUSDC_Count);
        emit WithdrawEvent(msg.sender, WUSDC_Count);
        return WUSDC_Count;
    }
}

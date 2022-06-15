// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "./LiquidityPoolInterfaces.sol";

/**
 * @author Prithviraj Murthy
 * @title Cruize USDC Liquidity Pool
 * @notice ####
 */
contract USDCPool is
    LiquidityPoolInterfaces,
    Ownable,
    ERC20("Cruize USDC LP Token", "writeUSDC")
{
    using SafeMath for uint256;
    address constant USDC_Token_Address = 0xb7a4F3E9097C08dA09517b5aB877F7a917224ede;

    /*
     * @nonce Sends premiums to the liquidity pool
     **/
    receive() external payable {}

    /*
     * @nonce A provider supplies USDC to the pool and receives writeUSDC tokens
     * @param minMint Minimum amount of tokens that should be received by a provider.
      Calling the provide function will require the minimum amount of tokens to be minted.
      The actual amount that will be minted could vary but can only be higher (not lower) than the minimum value.
     * @return mint Amount of tokens to be received
     */
    function provide(uint256 USDC_Count) external returns (uint256) {
        // we will send form the front
        require(USDC_Count > 0, "Pool: Amount is too small");
        
        IERC20 token = IERC20(USDC_Token_Address);
        require(
            token.transferFrom(msg.sender, address(this), USDC_Count),
            "Token transfer fails, Please try again."
        );
        _mint(msg.sender, USDC_Count * 10**uint(decimals()));
        emit Provide(msg.sender, USDC_Count);
        return USDC_Count;
    }

    /*
     * @nonce Provider burns writeUSDC and receives USDC from the pool
     * @param amount Amount of USDC to receive
     * @return burn Amount of tokens to be burnt
     */
    function withdraw(uint256 WUSDC_Count) external returns (uint256) {
        require(
            WUSDC_Count <= balanceOf(msg.sender),
            "Pool: Amount is too large"
        );
       
        require(WUSDC_Count > 0, "Pool: Amount is too small");
        _burn(msg.sender, WUSDC_Count * 10**uint(decimals()));
        IERC20 token = IERC20(USDC_Token_Address);
        token.transfer(msg.sender, WUSDC_Count);
        emit Withdraw(msg.sender, WUSDC_Count);
        return WUSDC_Count;
    }
}

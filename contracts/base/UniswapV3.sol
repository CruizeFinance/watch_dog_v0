// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";
import "../interfaces/IWETH.sol";
import "../libraries/BytesLib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/base/LiquidityManagement.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

contract UniswapV3 is IERC721Receiver {
    using BytesLib for bytes;

    // prettier-ignore
    ISwapRouter public constant ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    // prettier-ignore
    IWETH public constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    uint256 private constant PATH_SIZE = 43; // address + address + uint24
    uint256 private constant ADDRESS_SIZE = 20;

    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }
    mapping(uint256 => Deposit) public deposits;

    /**
     * @notice Calls the mint function defined in periphery, mints the same amount of each token.
     * @param token0 token0 address
     * @param token1 token1 address
     * @param amount0ToMint amount to mint of token0
     * @param amount1ToMint amount to mint of token1
     * @param tickLower lower tick
     * @param tickUpper upper tick
     * @return tokenId The id of the newly minted ERC721
     * @return liquidity The amount of liquidity for the position
     * @return amount0 The amount of token0
     * @return amount1 The amount of token1
     */
    function mintNewPosition(
        address token0,
        address token1,
        uint256 amount0ToMint,
        uint256 amount1ToMint,
        uint24 tickLower,
        uint24 tickUpper
    )
        external
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // Approve the position manager
        TransferHelper.safeApprove(
            token0,
            address(nonfungiblePositionManager),
            amount0ToMint
        );
        TransferHelper.safeApprove(
            token1,
            address(nonfungiblePositionManager),
            amount1ToMint
        );

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: poolFee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0ToMint,
                amount1Desired: amount1ToMint,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager
            .mint(params);

        // Create a deposit
        _createDeposit(msg.sender, tokenId);

        // Remove allowance and refund in both assets.
        if (amount0 < amount0ToMint) {
            TransferHelper.safeApprove(
                token0,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund0 = amount0ToMint - amount0;
            TransferHelper.safeTransfer(token0, msg.sender, refund0);
        }

        if (amount1 < amount1ToMint) {
            TransferHelper.safeApprove(
                token1,
                address(nonfungiblePositionManager),
                0
            );
            uint256 refund1 = amount1ToMint - amount1;
            TransferHelper.safeTransfer(token1, msg.sender, refund1);
        }
    }

    /**
     * @notice Increases liquidity in the current range
     * @dev Pool must be initialized already to add liquidity
     * @param tokenId The id of the erc721 token
     * @param amount0 The amount to add of token0
     * @param amount1 The amount to add of token1
     */
    function increaseLiquidityCurrentRange(
        uint256 tokenId,
        uint256 amountAdd0,
        uint256 amountAdd1
    )
        external
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        TransferHelper.safeTransferFrom(
            deposits[tokenId].token0,
            msg.sender,
            address(this),
            amountAdd0
        );
        TransferHelper.safeTransferFrom(
            deposits[tokenId].token1,
            msg.sender,
            address(this),
            amountAdd1
        );

        TransferHelper.safeApprove(
            deposits[tokenId].token0,
            address(nonfungiblePositionManager),
            amountAdd0
        );
        TransferHelper.safeApprove(
            deposits[tokenId].token1,
            address(nonfungiblePositionManager),
            amountAdd1
        );

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: amountAdd0,
                    amount1Desired: amountAdd1,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (liquidity, amount0, amount1) = nonfungiblePositionManager
            .increaseLiquidity(params);
    }

    /**
     * @notice A function that decreases the current liquidity
     * @param tokenId The id of the erc721 token
     * @param liquidity amount of liquidity want to decrease/withdraw
     * @return amount0 The amount received back in token0
     * @return amount1 The amount returned back in token1
     */
    function decreaseLiquidityInHalf(uint256 tokenId, uint256 liquidity)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        // caller must be the owner of the NFT
        require(msg.sender == deposits[tokenId].owner, "Not the owner");
        // get liquidity data for tokenId
        require(liquidity <= deposits[tokenId].liquidity);

        // amount0Min and amount1Min are price slippage checks
        // if the amount received after burning is not greater than these minimums, transaction will fail
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(
            params
        );
        //send liquidity back to owner
        _sendToOwner(tokenId, amount0, amount1);
    }

    /**
     * @notice Collects the fees associated with provided liquidity
     * @dev The contract must hold the erc721 token before it can collect fees
     * @param tokenId The id of the erc721 token
     * @return amount0 The amount of fees collected in token0
     * @return amount1 The amount of fees collected in token1
     */
    function collectAllFees(uint256 tokenId)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        // Caller must own the ERC721 position
        // Call to safeTransfer will trigger `onERC721Received` which must return the selector else transfer will fail
        nonfungiblePositionManager.safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        // set amount0Max and amount1Max to uint256.max to collect all fees
        // alternatively can set recipient to msg.sender and avoid another transaction in `sendToOwner`
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = nonfungiblePositionManager.collect(params);

        // send collected feed back to owner
        _sendToOwner(tokenId, amount0, amount1);
    }

    function _createDeposit(address owner, uint256 tokenId) internal {
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = nonfungiblePositionManager.positions(tokenId);

        // set the owner and data for position
        // operator is msg.sender
        deposits[tokenId] = Deposit({
            owner: owner,
            liquidity: liquidity,
            token0: token0,
            token1: token1
        });
    }

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        // get position information
        _createDeposit(operator, tokenId);
        return this.onERC721Received.selector;
    }

    /**
     * @notice Transfers funds to owner of NFT
     * @param tokenId The id of the erc721
     * @param amount0 The amount of token0
     * @param amount1 The amount of token1
     */
    function _sendToOwner(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) internal {
        // get owner of contract
        address owner = deposits[tokenId].owner;

        address token0 = deposits[tokenId].token0;
        address token1 = deposits[tokenId].token1;
        // send collected fees to owner
        TransferHelper.safeTransfer(token0, owner, amount0);
        TransferHelper.safeTransfer(token1, owner, amount1);
    }

    function exactInputSingleFromEther(
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96
    ) external payable returns (uint256 amountOut) {
        // Build params for router call
        ISwapRouter.ExactInputSingleParams memory params;
        params.tokenIn = address(WETH);
        params.tokenOut = tokenOut;
        params.fee = fee;
        params.amountIn = amountIn;
        params.amountOutMinimum = 0;
        params.sqrtPriceLimitX96 = 0;

        amountOut = _exactInputSingle(params.amountIn, params);
    }

    function _tokenApprove(
        address token,
        address spender,
        uint256 amount
    ) internal {
        try IERC20(token).approve(spender, amount) {} catch {
            IERC20(token).approve(spender, 0);
            IERC20(token).approve(spender, amount);
        }
    }

    function _tokenApproveZero(address token, address spender) internal {
        if (IERC20(token).allowance(address(this), spender) > 0) {
            try IERC20(token).approve(spender, 0) {} catch {
                IERC20(token).approve(spender, 1);
            }
        }
    }

    function _revertMsg(string memory functionName, string memory reason)
        internal
        pure
    {
        revert(string(abi.encodePacked(functionName, ": ", reason)));
    }

    function _revertMsg(string memory functionName) internal pure {
        _revertMsg(functionName, "Unspecified");
    }

    function _requireMsg(
        bool condition,
        string memory functionName,
        string memory reason
    ) internal pure {
        if (!condition) _revertMsg(functionName, reason);
    }

    function exactInputSingleToEther(
        address tokenIn,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96
    ) external payable returns (uint256 amountOut) {
        // Build params for router call
        ISwapRouter.ExactInputSingleParams memory params;
        params.tokenIn = tokenIn;
        params.tokenOut = address(WETH);
        params.fee = fee;
        params.amountIn = amountIn;
        params.amountOutMinimum = 0;
        params.sqrtPriceLimitX96 = 0;

        // Approve token
        _tokenApprove(tokenIn, address(ROUTER), params.amountIn);
        amountOut = _exactInputSingle(0, params);
        _tokenApproveZero(tokenIn, address(ROUTER));
        WETH.withdraw(amountOut);
    }

    function exactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96
    ) external payable returns (uint256 amountOut) {
        // Build params for router call
        ISwapRouter.ExactInputSingleParams memory params;
        params.tokenIn = tokenIn;
        params.tokenOut = tokenOut;
        params.fee = fee;
        params.amountIn = amountIn;
        params.amountOutMinimum = 0;
        params.sqrtPriceLimitX96 = 0;

        // Approve token
        _tokenApprove(tokenIn, address(ROUTER), params.amountIn);
        amountOut = _exactInputSingle(0, params);
        _tokenApproveZero(tokenIn, address(ROUTER));
    }

    function exactInputFromEther(
        bytes memory path,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external payable returns (uint256 amountOut) {
        console.logBytes(path);

        // Extract tokenIn and tokenOut
        address tokenIn = _getFirstToken(path);
        address tokenOut = _getLastToken(path);
        // Input token must be WETH
        require(tokenIn == address(WETH), "exactInputFromEther");
        // Build params for router call
        ISwapRouter.ExactInputParams memory params;
        params.path = path;
        params.amountIn = amountIn;
        params.amountOutMinimum = amountOutMinimum;

        amountOut = _exactInput(params.amountIn, params);
    }

    function exactInputToEther(
        bytes memory path,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external payable returns (uint256 amountOut) {
        // Extract tokenIn and tokenOut
        address tokenIn = _getFirstToken(path);
        address tokenOut = _getLastToken(path);
        // Output token must be WETH
        require(
            tokenOut == address(WETH),
            "exactInputToEther::Output not WETH"
        );
        // Build params for router call
        ISwapRouter.ExactInputParams memory params;
        params.path = path;
        params.amountIn = amountIn;
        params.amountOutMinimum = amountOutMinimum;

        // Approve token
        _tokenApprove(tokenIn, address(ROUTER), params.amountIn);
        amountOut = _exactInput(0, params);
        _tokenApproveZero(tokenIn, address(ROUTER));
        WETH.withdraw(amountOut);
    }

    function exactInput(
        bytes memory path,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external payable returns (uint256 amountOut) {
        // Extract tokenIn and tokenOut
        address tokenIn = _getFirstToken(path);
        address tokenOut = _getLastToken(path);
        // Build params for router call
        ISwapRouter.ExactInputParams memory params;
        params.path = path;
        params.amountIn = amountIn;
        params.amountOutMinimum = amountOutMinimum;

        // Approve token
        _tokenApprove(tokenIn, address(ROUTER), params.amountIn);
        amountOut = _exactInput(0, params);
        _tokenApproveZero(tokenIn, address(ROUTER));
    }

    function exactOutputSingleFromEther(
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint160 sqrtPriceLimitX96
    ) external payable returns (uint256 amountIn) {
        // Build params for router call
        ISwapRouter.ExactOutputSingleParams memory params;
        params.tokenIn = address(WETH);
        params.tokenOut = tokenOut;
        params.fee = fee;
        params.amountOut = amountOut;
        // if amount == type(uint256).max return balance of Proxy
        params.amountInMaximum = amountInMaximum;
        params.sqrtPriceLimitX96 = 0;
        amountIn = _exactOutputSingle(params.amountInMaximum, params);
        ROUTER.refundETH();
    }

    function exactOutputSingleToEther(
        address tokenIn,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint160 sqrtPriceLimitX96
    ) external payable returns (uint256 amountIn) {
        // Build params for router call
        ISwapRouter.ExactOutputSingleParams memory params;
        params.tokenIn = tokenIn;
        params.tokenOut = address(WETH);
        params.fee = fee;
        params.amountOut = amountOut;
        // if amount == type(uint256).max return balance of Proxy
        params.amountInMaximum = amountInMaximum;
        params.sqrtPriceLimitX96 = sqrtPriceLimitX96;

        // Approve token
        _tokenApprove(params.tokenIn, address(ROUTER), params.amountInMaximum);
        amountIn = _exactOutputSingle(0, params);
        _tokenApproveZero(params.tokenIn, address(ROUTER));
        WETH.withdraw(params.amountOut);
    }

    function exactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint256 amountInMaximum,
        uint160 sqrtPriceLimitX96
    ) external payable returns (uint256 amountIn) {
        // Build params for router call
        ISwapRouter.ExactOutputSingleParams memory params;
        params.tokenIn = tokenIn;
        params.tokenOut = tokenOut;
        params.fee = fee;
        params.amountOut = amountOut;
        // if amount == type(uint256).max return balance of Proxy
        params.amountInMaximum = amountInMaximum;
        params.sqrtPriceLimitX96 = sqrtPriceLimitX96;

        // Approve token
        _tokenApprove(params.tokenIn, address(ROUTER), params.amountInMaximum);
        amountIn = _exactOutputSingle(0, params);
        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(tokenIn, address(ROUTER), 0);
            TransferHelper.safeTransfer(
                tokenIn,
                msg.sender,
                amountInMaximum - amountIn
            );
        }
        _tokenApproveZero(params.tokenIn, address(ROUTER));
    }

    function exactOutputFromEther(
        bytes memory path,
        uint256 amountOut,
        uint256 amountInMaximum
    ) external payable returns (uint256 amountIn) {
        // Extract tokenIn and tokenOut
        // Note that the first token is tokenOut in exactOutput functions, vice versa
        address tokenIn = _getLastToken(path);
        address tokenOut = _getFirstToken(path);
        // Input token must be WETH
        require(
            tokenIn == address(WETH),
            "exactOutputFromEther::Input not WETH"
        );
        // Build params for router call
        ISwapRouter.ExactOutputParams memory params;
        params.path = path;
        params.amountOut = amountOut;
        params.amountInMaximum = amountInMaximum;

        amountIn = _exactOutput(params.amountInMaximum, params);
        ROUTER.refundETH();
    }

    function exactOutputToEther(
        bytes memory path,
        uint256 amountOut,
        uint256 amountInMaximum
    ) external payable returns (uint256 amountIn) {
        // Extract tokenIn and tokenOut
        // Note that the first token is tokenOut in exactOutput functions, vice versa
        address tokenIn = _getLastToken(path);
        address tokenOut = _getFirstToken(path);
        // Out token must be WETH
        require(
            tokenOut == address(WETH),
            "exactOutputToEther::Output not WETH"
        );
        // Build params for router call
        ISwapRouter.ExactOutputParams memory params;
        params.path = path;
        params.amountOut = amountOut;
        // if amount == type(uint256).max return balance of Proxy
        params.amountInMaximum = amountInMaximum;

        // Approve token
        _tokenApprove(tokenIn, address(ROUTER), params.amountInMaximum);
        amountIn = _exactOutput(0, params);
        _tokenApproveZero(tokenIn, address(ROUTER));
        WETH.withdraw(amountOut);
    }

    function exactOutput(
        bytes memory path,
        uint256 amountOut,
        uint256 amountInMaximum
    ) external payable returns (uint256 amountIn) {
        // Extract tokenIn and tokenOut
        // Note that the first token is tokenOut in exactOutput functions, vice versa
        address tokenIn = _getLastToken(path);
        address tokenOut = _getFirstToken(path);
        // Build params for router call
        ISwapRouter.ExactOutputParams memory params;
        params.path = path;
        params.amountOut = amountOut;
        // if amount == type(uint256).max return balance of Proxy
        params.amountInMaximum = amountInMaximum;

        // Approve token
        _tokenApprove(tokenIn, address(ROUTER), params.amountInMaximum);
        amountIn = _exactOutput(0, params);
        _tokenApproveZero(tokenIn, address(ROUTER));
    }

    function _getFirstToken(bytes memory path) internal pure returns (address) {
        return path.toAddress(0);
    }

    function _getLastToken(bytes memory path) internal pure returns (address) {
        require(path.length >= PATH_SIZE, "General::Path size too small");
        return path.toAddress(path.length - ADDRESS_SIZE);
    }

    function _exactInputSingle(
        uint256 value,
        ISwapRouter.ExactInputSingleParams memory params
    ) internal returns (uint256) {
        params.deadline = block.timestamp;
        params.recipient = address(this);

        try ROUTER.exactInputSingle{value: value}(params) returns (
            uint256 amountOut
        ) {
            return amountOut;
        } catch Error(string memory reason) {
            _revertMsg("exactInputSingle", reason);
        } catch {
            _revertMsg("exactInputSingle");
        }
    }

    function _exactInput(
        uint256 value,
        ISwapRouter.ExactInputParams memory params
    ) internal returns (uint256) {
        params.deadline = block.timestamp;
        params.recipient = address(this);

        try ROUTER.exactInput{value: value}(params) returns (
            uint256 amountOut
        ) {
            return amountOut;
        } catch Error(string memory reason) {
            _revertMsg("exactInput", reason);
        } catch {
            _revertMsg("exactInput");
        }
    }

    function _exactOutputSingle(
        uint256 value,
        ISwapRouter.ExactOutputSingleParams memory params
    ) internal returns (uint256) {
        params.deadline = block.timestamp;
        params.recipient = address(this);

        try ROUTER.exactOutputSingle{value: value}(params) returns (
            uint256 amountIn
        ) {
            return amountIn;
        } catch Error(string memory reason) {
            _revertMsg("exactOutputSingle", reason);
        } catch {
            _revertMsg("exactOutputSingle");
        }
    }

    function _exactOutput(
        uint256 value,
        ISwapRouter.ExactOutputParams memory params
    ) internal returns (uint256) {
        params.deadline = block.timestamp;
        params.recipient = address(this);

        try ROUTER.exactOutput{value: value}(params) returns (
            uint256 amountIn
        ) {
            return amountIn;
        } catch Error(string memory reason) {
            _revertMsg("exactOutput", reason);
        } catch {
            _revertMsg("exactOutput");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";

interface IUniswapV2Facet is IGenericMoreVaultFacetInitializable {
    error UnsupportedAsset(address);

    function facetName() external pure returns (string memory);

    function accountingUniswapV2Facet() external view returns (uint sum);

    /**
     * @notice Add liquidity to a pool
     * @param router The router address
     * @param tokenA The token A address
     * @param tokenB The token B address
     * @param amountADesired The amount of token A desired
     * @param amountBDesired The amount of token B desired
     * @param amountAMin The minimum amount of token A
     * @param amountBMin The minimum amount of token B
     * @param deadline The deadline
     * @return amountA The amount of token A
     * @return amountB The amount of token B
     * @return liquidity The liquidity
     */
    function addLiquidity(
        address router,
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    /**
     * @notice Add liquidity to a pool with ETH
     * @param router The router address
     * @param token The token address
     * @param amountTokenDesired The amount of token desired
     * @param amountETHDesired The amount of ETH desired
     * @param amountTokenMin The minimum amount of token
     * @param amountETHMin The minimum amount of ETH
     * @param deadline The deadline
     * @return amountToken The amount of token
     * @return amountETH The amount of ETH
     * @return liquidity The liquidity
     */
    function addLiquidityETH(
        address router,
        address token,
        uint amountTokenDesired,
        uint amountETHDesired,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    ) external returns (uint amountToken, uint amountETH, uint liquidity);

    /**
     * @notice Remove liquidity from a pool
     * @param router The router address
     * @param tokenA The token A address
     * @param tokenB The token B address
     * @param liquidity The liquidity
     * @param amountAMin The minimum amount of token A
     * @param amountBMin The minimum amount of token B
     * @param deadline The deadline
     * @return amountA The amount of token A
     * @return amountB The amount of token B
     */
    function removeLiquidity(
        address router,
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    /**
     * @notice Remove liquidity from a pool with ETH
     * @param router The router address
     * @param token The token address
     * @param liquidity The liquidity
     * @param amountTokenMin The minimum amount of token
     * @param amountETHMin The minimum amount of ETH
     * @param deadline The deadline
     * @return amountToken The amount of token
     * @return amountETH The amount of ETH
     */
    function removeLiquidityETH(
        address router,
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    /**
     * @notice Swap exact tokens for tokens
     * @param router The router address
     * @param amountIn The amount of token in
     * @param amountOutMin The minimum amount of token out
     * @param path The path
     * @param deadline The deadline
     * @return amounts The amounts
     */
    function swapExactTokensForTokens(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts);

    /**
     * @notice Swap tokens for exact tokens
     * @param router The router address
     * @param amountOut The amount of token out
     * @param amountInMax The maximum amount of token in
     * @param path The path
     * @param deadline The deadline
     * @return amounts The amounts
     */
    function swapTokensForExactTokens(
        address router,
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts);

    /**
     * @notice Swap exact ETH for tokens
     * @param router The router address
     * @param amountIn The amount of ETH in
     * @param amountOutMin The minimum amount of token out
     * @param path The path
     * @param deadline The deadline
     * @return amounts The amounts
     */
    function swapExactETHForTokens(
        address router,
        uint256 amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts);

    /**
     * @notice Swap tokens for exact ETH
     * @param router The router address
     * @param amountOut The amount of token out
     * @param amountInMax The maximum amount of token in
     * @param path The path
     * @param deadline The deadline
     * @return amounts The amounts
     */
    function swapTokensForExactETH(
        address router,
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts);

    /**
     * @notice Swap exact tokens for ETH
     * @param router The router address
     * @param amountIn The amount of token in
     * @param amountOutMin The minimum amount of ETH out
     * @param path The path
     * @param deadline The deadline
     * @return amounts The amounts
     */
    function swapExactTokensForETH(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts);

    /**
     * @notice Swap ETH for exact tokens
     * @param router The router address
     * @param amountInMax The maximum amount of ETH in
     * @param amountOut The amount of token out
     * @param path The path
     * @param deadline The deadline
     * @return amounts The amounts
     */
    function swapETHForExactTokens(
        address router,
        uint256 amountInMax,
        uint amountOut,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts);

    /**
     * @notice Remove liquidity from a pool supporting fee on transfer tokens
     * @param router The router address
     * @param token The token address
     * @param liquidity The liquidity
     * @param amountTokenMin The minimum amount of token
     * @param amountETHMin The minimum amount of ETH
     * @param deadline The deadline
     * @return amountETH The amount of ETH
     */
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address router,
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    ) external returns (uint amountETH);

    /**
     * @notice Swap exact tokens for tokens supporting fee on transfer tokens
     * @param router The router address
     * @param amountIn The amount of token in
     * @param amountOutMin The minimum amount of token out
     * @param path The path
     * @param deadline The deadline
     */
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external;

    /**
     * @notice Swap exact ETH for tokens supporting fee on transfer tokens
     * @param router The router address
     * @param amountIn The amount of ETH in
     * @param amountOutMin The minimum amount of token out
     * @param path The path
     * @param deadline The deadline
     */
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        address router,
        uint256 amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external;

    /**
     * @notice Swap exact tokens for ETH supporting fee on transfer tokens
     * @param router The router address
     * @param amountIn The amount of token in
     * @param amountOutMin The minimum amount of ETH out
     * @param path The path
     * @param deadline The deadline
     */
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external;
}

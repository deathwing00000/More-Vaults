// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";

interface IUniswapV2Facet is IGenericMoreVaultFacetInitializable {
    error UnsupportedAsset(address);

    function facetName() external pure returns (string memory);

    // function withdrawFromUniswapV2Facet(uint proportion, address to) external;

    function accountingUniswapV2Facet() external view returns (uint sum);

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

    function addLiquidityETH(
        address router,
        address token,
        uint amountTokenDesired,
        uint amountETHDesired,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    ) external returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidity(
        address router,
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETH(
        address router,
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokens(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        address router,
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        address router,
        uint256 amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactETH(
        address router,
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokens(
        address router,
        uint256 amountInMax,
        uint amountOut,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address router,
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        address router,
        uint256 amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external;
}

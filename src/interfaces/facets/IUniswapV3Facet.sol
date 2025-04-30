// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ISwapRouter} from "../Uniswap/v3/ISwapRouter.sol";
import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";

/// @title IUniswapV3Facet
/// @notice Interface for interacting with UniswapV3 DEX through a facet
/// @dev Implements functions for token swaps through the iZUMi protocol
interface IUniswapV3Facet is IGenericMoreVaultFacetInitializable {
    /// @notice Error thrown when attempting to swap an unsupported asset
    /// @param asset Address of the unsupported asset
    error UnsupportedAsset(address asset);

    function exactInputSingle(
        address router,
        ISwapRouter.ExactInputSingleParams memory params
    ) external payable returns (uint256 amountOut);

    function exactInput(
        address router,
        ISwapRouter.ExactInputParams memory params
    ) external payable returns (uint256 amountOut);

    function exactOutputSingle(
        address router,
        ISwapRouter.ExactOutputSingleParams memory params
    ) external payable returns (uint256 amountIn);

    function exactOutput(
        address router,
        ISwapRouter.ExactOutputParams memory params
    ) external payable returns (uint256 amountIn);
}

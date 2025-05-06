// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";

/// @title ICurveFacet
/// @notice Interface for interacting with Curve protocol through a facet
/// @dev Implements functions for token exchanges through the Curve protocol
interface ICurveFacet is IGenericMoreVaultFacetInitializable {
    /// @notice Error thrown when attempting to swap an unsupported asset
    /// @param asset Address of the unsupported asset
    error UnsupportedAsset(address asset);

    function accountingCurveFacet() external view returns (uint256);

    /// @notice Performs up to 5 swaps in a single transaction.
    /// @param curveRouter Address of the Curve router contract
    /// @param _route Array of [initial token, pool or zap, token, pool or zap, token, ...]
    /// @param _swap_params Multidimensional array of [i, j, swap_type, pool_type, n_coins] where
    /// @param _amount The amount of input token (`_route[0]`) to be sent.
    /// @param _min_dy The minimum amount received after the final swap.
    /// @param _pools Array of pools for swaps via zap contracts. This parameter is only needed for swap_type = 3.
    /// @return Received amount of the final output token.
    function exchange(
        address curveRouter,
        address[11] calldata _route,
        uint256[5][5] calldata _swap_params,
        uint256 _amount,
        uint256 _min_dy,
        address[5] calldata _pools
    ) external payable returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISwap} from "../iZUMi/ISwap.sol";
import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";

/// @title IIzumiSwapFacet
/// @notice Interface for interacting with iZUMi DEX through a facet
/// @dev Implements functions for token swaps through the iZUMi protocol
interface IIzumiSwapFacet is IGenericMoreVaultFacetInitializable {
    /// @notice Error thrown when attempting to swap an unsupported asset
    /// @param asset Address of the unsupported asset
    error UnsupportedAsset(address asset);

    /// @notice Performs a swap with a fixed amount of input tokens
    /// @param swapContract Address of the iZUMi contract to execute the swap
    /// @param params Swap parameters including paths, amounts, and other settings
    /// @return cost Amount of input tokens spent on the swap
    /// @return acquire Amount of output tokens received
    function swapAmount(
        address swapContract,
        ISwap.SwapAmountParams calldata params
    ) external payable returns (uint256 cost, uint256 acquire);

    /// @notice Performs a swap with a fixed amount of output tokens
    /// @param swapContract Address of the iZUMi contract to execute the swap
    /// @param params Swap parameters including paths, desired amount, and other settings
    /// @return cost Amount of input tokens spent on the swap
    /// @return acquire Amount of output tokens received
    function swapDesire(
        address swapContract,
        ISwap.SwapDesireParams calldata params
    ) external payable returns (uint256 cost, uint256 acquire);
}

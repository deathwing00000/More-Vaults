// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Interface for SwapRouter
interface ISwap {
    struct SwapAmountParams {
        bytes path;
        address recipient;
        uint128 amount;
        uint256 minAcquired;
        uint256 deadline;
    }

    /// @notice Swap given amount of input token, usually used in multi-hop case.
    function swapAmount(
        SwapAmountParams calldata params
    ) external payable returns (uint256 cost, uint256 acquire);

    struct SwapDesireParams {
        bytes path;
        address recipient;
        uint128 desire;
        uint256 maxPayed;
        uint256 deadline;
    }

    /// @notice Swap given amount of target token, usually used in multi-hop case.
    function swapDesire(
        SwapDesireParams calldata params
    ) external payable returns (uint256 cost, uint256 acquire);
}

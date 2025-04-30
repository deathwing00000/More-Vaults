// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";
import {IAggroKittyRouter} from "../KittyPunch/IAggroKittyRouter.sol";

interface IAggroKittySwapFacet is IGenericMoreVaultFacetInitializable {
    /**
     * @notice Swaps tokens without splitting the trade
     * @param _router The address of the router
     * @param _trade The trade to swap
     */
    function swapNoSplit(
        address _router,
        IAggroKittyRouter.Trade calldata _trade
    ) external;

    /**
     * @notice Swaps tokens without splitting the trade from native
     * @param _router The address of the router
     * @param _trade The trade to swap
     */
    function swapNoSplitFromNative(
        address _router,
        IAggroKittyRouter.Trade calldata _trade
    ) external;

    /**
     * @notice Swaps tokens without splitting the trade to native
     * @param _router The address of the router
     * @param _trade The trade to swap
     */
    function swapNoSplitToNative(
        address _router,
        IAggroKittyRouter.Trade calldata _trade
    ) external;
}

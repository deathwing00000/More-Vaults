// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";
import {IAggroKittyRouter} from "../KittyPunch/IAggroKittyRouter.sol";

interface IAggroKittySwapFacet is IGenericMoreVaultFacetInitializable {
    function swapNoSplit(
        address _router,
        IAggroKittyRouter.Trade calldata _trade
    ) external;

    function swapNoSplitFromNative(
        address _router,
        IAggroKittyRouter.Trade calldata _trade
    ) external;

    function swapNoSplitToNative(
        address _router,
        IAggroKittyRouter.Trade calldata _trade
    ) external;
}

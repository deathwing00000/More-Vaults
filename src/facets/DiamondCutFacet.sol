// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IDiamondCut} from "../interfaces/facets/IDiamondCut.sol";
import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";

contract DiamondCutFacet is IDiamondCut {
    function facetName() external pure returns (string memory) {
        return "DiamondCutFacet";
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    function diamondCut(
        IDiamondCut.FacetCut[] calldata _diamondCut
    ) external override {
        AccessControlLib.validateCurator(msg.sender);
        MoreVaultsLib.diamondCut(_diamondCut);
    }
}

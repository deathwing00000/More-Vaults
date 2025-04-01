// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IDiamondCut} from "../interfaces/facets/IDiamondCut.sol";
import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";

contract DiamondCutFacet is BaseFacetInitializer, IDiamondCut {
    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.DiamondCutFacet");
    }

    function facetName() external pure returns (string memory) {
        return "DiamondCutFacet";
    }

    function initialize(bytes calldata) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    function diamondCut(
        IDiamondCut.FacetCut[] calldata _diamondCut
    ) external override {
        AccessControlLib.validateOwner(msg.sender);
        MoreVaultsLib.diamondCut(_diamondCut);
    }
}

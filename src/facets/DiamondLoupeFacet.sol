// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {IDiamondLoupe} from "../interfaces/facets/IDiamondLoupe.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";

contract DiamondLoupeFacet is BaseFacetInitializer, IDiamondLoupe, IERC165 {
    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.DiamondLoupeFacet");
    }

    function facetName() external pure returns (string memory) {
        return "DiamondLoupeFacet";
    }

    function initialize(bytes calldata) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
    }

    /// @notice Gets all facets and their selectors.
    /// @return facets_ Facet
    function facets() external view override returns (Facet[] memory facets_) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        uint256 numFacets = ds.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = ds
                .facetFunctionSelectors[facetAddress_]
                .functionSelectors;
        }
    }

    /// @notice Gets all the function selectors provided by a facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(
        address _facet
    ) external view override returns (bytes4[] memory facetFunctionSelectors_) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        facetFunctionSelectors_ = ds
            .facetFunctionSelectors[_facet]
            .functionSelectors;
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses()
        external
        view
        override
        returns (address[] memory facetAddresses_)
    {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        facetAddresses_ = ds.facetAddresses;
    }

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(
        bytes4 _functionSelector
    ) external view override returns (address facetAddress_) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        facetAddress_ = ds
            .selectorToFacetAndPosition[_functionSelector]
            .facetAddress;
    }

    // This implements ERC-165.
    function supportsInterface(
        bytes4 _interfaceId
    ) external view override returns (bool) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        return ds.supportedInterfaces[_interfaceId];
    }
}

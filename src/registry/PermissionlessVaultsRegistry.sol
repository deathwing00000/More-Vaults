// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseVaultsRegistry} from "./BaseVaultsRegistry.sol";

/**
 * @title PermissionlessVaultsRegistry
 * @notice Registry contract that allows all facets by default.
 */
contract PermissionlessVaultsRegistry is BaseVaultsRegistry {
    error AllFacetsAllowedByDefault();
    error FeeCannotBeSet();
    error AllProtocolsWhitelistedByDefault();

    function _isFacetAllowed(address) internal pure override returns (bool) {
        return true;
    }

    /**
     * @notice This function is disabled in PermissionlessVaultsRegistry as all facets are allowed by default
     */
    function addFacet(address, bytes4[] calldata) external pure override {
        revert AllFacetsAllowedByDefault();
    }

    /**
     * @notice This function is disabled in PermissionlessVaultsRegistry as all facets are allowed by default
     */
    function removeFacet(address) external pure override {
        revert AllFacetsAllowedByDefault();
    }

    /**
     * @notice This function is disabled in PermissionlessVaultsRegistry as protocol fee cannot be set
     */
    function setProtocolFeeInfo(
        address,
        address,
        uint96
    ) external view override onlyRole(DEFAULT_ADMIN_ROLE) {
        revert FeeCannotBeSet();
    }

    /**
     * @notice This function is disabled in PermissionlessVaultsRegistry as protocol fee cannot be set
     */
    function protocolFeeInfo(
        address
    ) external pure override returns (address, uint96) {
        return (address(0), 0);
    }

    /**
     * @notice This function is disabled in PermissionlessVaultsRegistry as protocol fee cannot be set
     */
    function addToWhitelist(address) external pure override {
        revert AllProtocolsWhitelistedByDefault();
    }

    /**
     * @notice This function is disabled in PermissionlessVaultsRegistry as protocol fee cannot be set
     */
    function removeFromWhitelist(address) external pure override {
        revert AllProtocolsWhitelistedByDefault();
    }

    /**
     * @notice This function always returns true in PermissionlessVaultsRegistry as all protocols are whitelisted by default
     */
    function isWhitelisted(address) external pure override returns (bool) {
        return true;
    }

    // function linkFacet(address) external pure override {
    //     revert AllFacetsAllowedByDefault();
    // }

    // function unlinkFacet(address) external pure override {
    //     revert AllFacetsAllowedByDefault();
    // }
}

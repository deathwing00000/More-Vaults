// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {IAccessControlFacet} from "../interfaces/facets/IAccessControlFacet.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";

contract AccessControlFacet is IAccessControlFacet {
    function facetName() external pure returns (string memory) {
        return "AccessControlFacet";
    }

    function setMoreVaultRegistry(address newRegistry) external {
        AccessControlLib.validateRegistryOwner(msg.sender);
        if (newRegistry == address(0)) {
            revert AccessControlLib.ZeroAddress();
        }
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        AccessControlLib.AccessControlStorage storage acs = AccessControlLib
            .accessControlStorage();

        if (acs.moreVaultsRegistry == newRegistry) {
            revert AccessControlLib.SameAddress();
        }

        address previousRegistry = acs.moreVaultsRegistry;
        acs.moreVaultsRegistry = newRegistry;

        // Check if all existing facets and their selectors are allowed in the new registry
        IMoreVaultsRegistry registry = IMoreVaultsRegistry(newRegistry);

        // Get all facet addresses
        address[] memory facetAddresses = ds.facetAddresses;

        // Check each facet and its selectors
        for (uint256 i; i < facetAddresses.length; ) {
            address facet = facetAddresses[i];
            if (!registry.isFacetAllowed(facet)) {
                revert VaultHasNotAllowedFacet(facet);
            }

            // Get all selectors for this facet
            MoreVaultsLib.FacetFunctionSelectors memory facetSelectorsInfo = ds
                .facetFunctionSelectors[facet];
            bytes4[] memory selectors = facetSelectorsInfo.functionSelectors;
            for (uint256 j; j < selectors.length; ) {
                bytes4 selector = selectors[j];
                if (registry.selectorToFacet(selector) != facet) {
                    revert VaultHasNotAllowedSelector(facet, selector);
                }
                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }

        emit MoreVaultRegistrySet(previousRegistry, newRegistry);
    }

    function transferCuratorship(address _newCurator) external {
        AccessControlLib.validateCurator(msg.sender);
        address previousCurator = AccessControlLib.vaultCurator();
        AccessControlLib.setVaultCurator(_newCurator);
        emit CuratorChanged(previousCurator, _newCurator);
    }

    function transferGuardian(address _newGuardian) external {
        AccessControlLib.validateGuardian(msg.sender);
        address previousGuardian = AccessControlLib.vaultGuardian();
        AccessControlLib.setVaultGuardian(_newGuardian);
        emit GuardianChanged(previousGuardian, _newGuardian);
    }

    function curator() external view returns (address) {
        return AccessControlLib.vaultCurator();
    }

    function guardian() external view returns (address) {
        return AccessControlLib.vaultGuardian();
    }
}

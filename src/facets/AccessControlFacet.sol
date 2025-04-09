// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {IAccessControlFacet} from "../interfaces/facets/IAccessControlFacet.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";

contract AccessControlFacet is BaseFacetInitializer, IAccessControlFacet {
    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.AccessControlFacet");
    }

    function facetName() external pure returns (string memory) {
        return "AccessControlFacet";
    }

    function initialize(bytes calldata data) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        (address _owner, address _curator, address _guardian) = abi.decode(
            data,
            (address, address, address)
        );

        AccessControlLib.setVaultOwner(_owner);
        AccessControlLib.setVaultCurator(_curator);
        AccessControlLib.setVaultGuardian(_guardian);

        ds.supportedInterfaces[type(IAccessControlFacet).interfaceId] = true; // AccessControlFacet
    }

    function setMoreVaultRegistry(address newRegistry) external {
        AccessControlLib.validateOwner(msg.sender);
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
            unchecked {
                ++i;
            }
        }

        emit MoreVaultRegistrySet(previousRegistry, newRegistry);
    }

    function transferOwner(address _newOwner) external {
        AccessControlLib.validateOwner(msg.sender);
        AccessControlLib.setVaultOwner(_newOwner);
    }

    function transferCuratorship(address _newCurator) external {
        AccessControlLib.validateOwner(msg.sender);
        AccessControlLib.setVaultCurator(_newCurator);
    }

    function transferGuardian(address _newGuardian) external {
        AccessControlLib.validateOwner(msg.sender);
        AccessControlLib.setVaultGuardian(_newGuardian);
    }

    function owner() external view returns (address) {
        return AccessControlLib.vaultOwner();
    }

    function curator() external view returns (address) {
        return AccessControlLib.vaultCurator();
    }

    function guardian() external view returns (address) {
        return AccessControlLib.vaultGuardian();
    }

    function moreVaultsRegistry() external view returns (address) {
        return AccessControlLib.vaultRegistry();
    }
}

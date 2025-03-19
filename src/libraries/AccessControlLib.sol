// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MoreVaultsLib} from "./MoreVaultsLib.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";

/**
 * @title AccessControlLib
 * @notice Library for managing access control in diamond proxy
 */
library AccessControlLib {
    /**
     * @dev Custom errors for access control
     */
    error UnauthorizedAccess();
    error ZeroAddress();
    error SameAddress();

    bytes32 constant ACCESS_CONTROL_STORAGE_POSITION =
        keccak256("MoreVaults.accessControl.storage");

    struct AccessControlStorage {
        address curator;
        address guardian;
        address moreVaultsRegistry;
    }

    function accessControlStorage()
        internal
        pure
        returns (AccessControlStorage storage acs)
    {
        bytes32 position = ACCESS_CONTROL_STORAGE_POSITION;
        // assigns struct storage slot to the storage position
        assembly {
            acs.slot := position
        }
    }

    function validateRegistryOwner(address caller) internal view {
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;
        if (
            !IAccessControl(accessControlStorage().moreVaultsRegistry).hasRole(
                DEFAULT_ADMIN_ROLE,
                caller
            )
        ) {
            revert UnauthorizedAccess();
        }
    }

    /**
     * @notice Validates if caller is curator
     * @param caller Address to validate
     */
    function validateCurator(address caller) internal view {
        if (caller != accessControlStorage().curator) {
            revert UnauthorizedAccess();
        }
    }

    /**
     * @notice Validates if caller is guardian
     * @param caller Address to validate
     */
    function validateGuardian(address caller) internal view {
        if (accessControlStorage().guardian != caller) {
            revert UnauthorizedAccess();
        }
    }

    function validateDiamond(address caller) internal view {
        if (caller != address(this)) {
            revert UnauthorizedAccess();
        }
    }

    /**
     * @notice Sets new curator address
     * @param _newCurator Address of new curator
     */
    function setVaultCurator(address _newCurator) internal {
        if (_newCurator == address(0)) {
            revert ZeroAddress();
        }

        AccessControlStorage storage acs = accessControlStorage();

        if (_newCurator == acs.curator) {
            revert SameAddress();
        }

        acs.curator = _newCurator;
    }

    /**
     * @notice Sets new guardian address
     * @param _newGuardian Address of new guardian
     */
    function setVaultGuardian(address _newGuardian) internal {
        if (_newGuardian == address(0)) {
            revert ZeroAddress();
        }

        AccessControlStorage storage acs = accessControlStorage();

        if (_newGuardian == acs.guardian) {
            revert SameAddress();
        }

        acs.guardian = _newGuardian;
    }

    /**
     * @notice Gets current curator address
     * @return Address of current curator
     */
    function vaultCurator() internal view returns (address) {
        return accessControlStorage().curator;
    }

    /**
     * @notice Gets current guardian address
     * @return Address of current guardian
     */
    function vaultGuardian() internal view returns (address) {
        return accessControlStorage().guardian;
    }

    function vaultRegistry() internal view returns (address) {
        return accessControlStorage().moreVaultsRegistry;
    }
}

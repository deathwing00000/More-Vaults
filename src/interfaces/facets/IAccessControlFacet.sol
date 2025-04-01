// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";

interface IAccessControlFacet is IGenericMoreVaultFacetInitializable {
    error VaultHasNotAllowedFacet(address facet);
    error VaultHasNotAllowedSelector(address facet, bytes4 selector);

    /**
     * @dev Emitted when more vault registry is changed
     */
    event MoreVaultRegistrySet(
        address indexed previousRegistry,
        address indexed newRegistry
    );

    /**
     * @notice Sets the more vault registry address
     * @param newRegistry Address of the new more vault registry
     */
    function setMoreVaultRegistry(address newRegistry) external;

    /**
     * @notice Transfers curator role to a new address
     * @param _newCurator Address of the new curator
     */
    function transferCuratorship(address _newCurator) external;

    /**
     * @notice Transfers guardian role to a new address
     * @param _newGuardian Address of the new guardian
     */
    function transferGuardian(address _newGuardian) external;

    /**
     * @notice Returns the current curator address
     * @return Address of the current curator
     */
    function curator() external view returns (address);

    /**
     * @notice Returns the current guardian address
     * @return Address of the current guardian
     */
    function guardian() external view returns (address);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IMoreVaultsRegistry} from "./IMoreVaultsRegistry.sol";
import {IDiamondCut} from "./facets/IDiamondCut.sol";

interface IVaultsFactory {
    error InvalidSelector(address facet, bytes4 selector);
    error ZeroAddress();
    error EmptyFacets();
    error InvalidTimeLock();
    error InvalidFee();

    event VaultDeployed(
        address indexed vault,
        address indexed asset,
        string name,
        string symbol,
        address indexed curator,
        address guardian,
        address registry
    );

    event DiamondCutFacetUpdated(address indexed newDiamondCutFacet);

    /**
     * @notice Get registry contract address
     * @return address Registry address
     */
    function registry() external view returns (IMoreVaultsRegistry);

    /**
     * @notice Check if vault was deployed by this factory
     * @param vault Address to check
     * @return bool True if vault was deployed by this factory
     */
    function isFactoryVault(address vault) external view returns (bool);

    /**
     * @notice Get vault by index
     * @param index Index of vault
     * @return address Vault address
     */
    function deployedVaults(uint256 index) external view returns (address);

    /**
     * @notice Deploy new vault instance
     * @param asset Underlying asset address
     * @param name Vault token name
     * @param symbol Vault token symbol
     * @param curator Curator address
     * @param guardian Guardian address
     * @param feeRecipient Fee recipient address
     * @param fee Initial fee (in basis points)
     * @param timeLockPeriod Time lock period for actions
     * @param facetCuts Array of facets to add
     * @return vault Address of deployed vault
     */
    function deployVault(
        address asset,
        string memory name,
        string memory symbol,
        address curator,
        address guardian,
        address feeRecipient,
        uint96 fee,
        uint256 timeLockPeriod,
        IDiamondCut.FacetCut[] calldata facetCuts
    ) external returns (address vault);

    /**
     * @notice Get all deployed vaults
     * @return Array of vault addresses
     */
    function getDeployedVaults() external view returns (address[] memory);

    /**
     * @notice Get number of deployed vaults
     * @return Number of vaults
     */
    function getVaultsCount() external view returns (uint256);

    /**
     * @notice Check if address is a vault deployed by this factory
     * @param vault Address to check
     * @return bool True if vault was deployed by this factory
     */
    function isVault(address vault) external view returns (bool);
}

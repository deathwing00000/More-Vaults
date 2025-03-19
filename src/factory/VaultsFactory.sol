// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {MoreVaultsDiamond} from "../MoreVaultsDiamond.sol";
import {DiamondCutFacet} from "../facets/DiamondCutFacet.sol";
import {IDiamondCut} from "../interfaces/facets/IDiamondCut.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";
import {IVaultsFactory} from "../interfaces/IVaultsFactory.sol";
import {IGenericMoreVaultFacetInitializable} from "../interfaces/facets/IGenericMoreVaultFacetInitializable.sol";
/**
 * @title VaultsFactory
 * @notice Factory contract for deploying new vault instances
 */
contract VaultsFactory is IVaultsFactory, AccessControl {
    /// @dev Registry contract address
    IMoreVaultsRegistry public immutable registry;

    /// @dev DiamondCutFacet address
    address public diamondCutFacet;

    /// @dev Mapping vault address => is deployed by this factory
    mapping(address => bool) public isFactoryVault;

    /// @dev Array of all deployed vaults
    address[] public deployedVaults;

    constructor(address _registry, address _diamondCutFacet) {
        if (_registry == address(0)) revert ZeroAddress();
        _setDiamondCutFacet(_diamondCutFacet);

        registry = IMoreVaultsRegistry(_registry);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setDiamondCutFacet(
        address _diamondCutFacet
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setDiamondCutFacet(_diamondCutFacet);
    }

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
     * @param facets Array of facets to add
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
        IDiamondCut.FacetCut[] calldata facets
    ) external override returns (address vault) {
        if (
            asset == address(0) ||
            curator == address(0) ||
            guardian == address(0) ||
            feeRecipient == address(0)
        ) revert ZeroAddress();
        if (timeLockPeriod == 0) revert InvalidTimeLock();
        if (fee > 10000) revert InvalidFee(); // max 100% = 10000 basis points

        // Convert FacetCut[] to IDiamondCut.FacetCut[]
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](
            facets.length
        );
        for (uint256 i = 0; i < facets.length; ) {
            cuts[i] = IDiamondCut.FacetCut({
                facetAddress: facets[i].facetAddress,
                action: facets[i].action,
                functionSelectors: facets[i].functionSelectors,
                initData: facets[i].initData
            });
            unchecked {
                ++i;
            }
        }
        // Deploy new MoreVaultsDiamond (vault)
        vault = address(
            new MoreVaultsDiamond(diamondCutFacet, address(registry), cuts)
        );
        isFactoryVault[vault] = true;
        deployedVaults.push(vault);
        emit VaultDeployed(
            vault,
            asset,
            name,
            symbol,
            curator,
            guardian,
            address(registry)
        );
    }

    /**
     * @notice Get all deployed vaults
     * @return Array of vault addresses
     */
    function getDeployedVaults()
        external
        view
        override
        returns (address[] memory)
    {
        return deployedVaults;
    }

    /**
     * @notice Get number of deployed vaults
     * @return Number of vaults
     */
    function getVaultsCount() external view override returns (uint256) {
        return deployedVaults.length;
    }

    /**
     * @notice Check if address is a vault deployed by this factory
     * @param vault Address to check
     * @return bool True if vault was deployed by this factory
     */
    function isVault(address vault) external view override returns (bool) {
        return isFactoryVault[vault];
    }

    function _setDiamondCutFacet(address _diamondCutFacet) internal {
        if (_diamondCutFacet == address(0)) revert ZeroAddress();
        diamondCutFacet = _diamondCutFacet;
        emit DiamondCutFacetUpdated(diamondCutFacet);
    }
}

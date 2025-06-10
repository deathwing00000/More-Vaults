// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BaseVaultsRegistry} from "./BaseVaultsRegistry.sol";
import {IVaultFacet} from "../interfaces/facets/IVaultFacet.sol";
import {IVaultsFactory} from "../interfaces/IVaultsFactory.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title VaultsRegistry
 * @notice Registry contract that stores information about allowed facets and their selectors
 */
contract VaultsRegistry is BaseVaultsRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    error InvalidFee();
    error NotFactoryVault(address);

    /// @dev Mapping of facet address => is allowed
    mapping(address => bool) private _allowedFacets;
    mapping(address => EnumerableSet.AddressSet) private _facetToVaults;
    address public factory;

    uint96 private constant MAX_PROTOCOL_FEE = 5000; // 50%

    function pauseAffectedVaults(address _facet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address[] memory vaults = _facetToVaults[_facet].values();
        for (uint i = 0; i < vaults.length; ) {
            IVaultFacet(vaults[i]).pause();
            unchecked {
                ++i;
            }
        }
    }

    function linkFacet(address facet) external {
        if (!IVaultsFactory(factory).isFactoryVault(msg.sender)) {
            revert NotFactoryVault(msg.sender);
        }

        _facetToVaults[facet].add(msg.sender);
    }

    function unlinkFacet(address facet) external {
        if (!IVaultsFactory(factory).isFactoryVault(msg.sender)) {
            revert NotFactoryVault(msg.sender);
        }
        _facetToVaults[facet].remove(msg.sender);
    }

    /**
     * @inheritdoc IMoreVaultsRegistry
     */
    function addFacet(
        address facet,
        bytes4[] calldata selectors
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (facet == address(0)) revert ZeroAddress();

        _allowedFacets[facet] = true;
        facetsList.push(facet);

        for (uint i = 0; i < selectors.length; ) {
            bytes4 selector = selectors[i];
            if (selectorToFacet[selector] != address(0))
                revert SelectorAlreadyExists(
                    selectorToFacet[selector],
                    selector
                );

            selectorToFacet[selector] = facet;
            facetSelectors[facet].push(selector);

            unchecked {
                ++i;
            }
        }

        emit FacetAdded(facet, selectors);
    }

    /**
     * @inheritdoc IMoreVaultsRegistry
     */
    function removeFacet(
        address facet
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!_allowedFacets[facet]) revert FacetNotAllowed(facet);

        // Remove from allowed facets
        _allowedFacets[facet] = false;

        // Remove from facets list
        for (uint i = 0; i < facetsList.length; ) {
            if (facetsList[i] == facet) {
                facetsList[i] = facetsList[facetsList.length - 1];
                facetsList.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        // Remove all selectors
        bytes4[] memory selectors = facetSelectors[facet];
        for (uint i = 0; i < selectors.length; ) {
            delete selectorToFacet[selectors[i]];
            unchecked {
                ++i;
            }
        }
        delete facetSelectors[facet];

        emit FacetRemoved(facet);
    }

    /**
     * @inheritdoc IMoreVaultsRegistry
     */
    function setProtocolFeeInfo(
        address vault,
        address recipient,
        uint96 fee
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (recipient == address(0)) revert ZeroAddress();
        if (fee > MAX_PROTOCOL_FEE) revert InvalidFee();

        _protocolFeeInfo[vault] = ProtocolFeeInfo({
            recipient: recipient,
            fee: fee
        });

        emit ProtocolFeeInfoUpdated(vault, recipient, fee);
    }

    /**
     * @inheritdoc IMoreVaultsRegistry
     */
    function protocolFeeInfo(
        address vault
    ) external view override returns (address, uint96) {
        return (_protocolFeeInfo[vault].recipient, _protocolFeeInfo[vault].fee);
    }

    /**
     * @inheritdoc IMoreVaultsRegistry
     */
    function addToWhitelist(
        address protocol
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setWhitelisted(protocol, true);
    }

    /**
     * @inheritdoc IMoreVaultsRegistry
     */
    function removeFromWhitelist(
        address protocol
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setWhitelisted(protocol, false);
    }

    function setFactoryAddress(address _factory) external onlyRole(DEFAULT_ADMIN_ROLE) {
        factory = _factory;
    }

    /**
     * @inheritdoc IMoreVaultsRegistry
     */
    function isWhitelisted(
        address protocol
    ) external view override returns (bool) {
        return _isWhitelisted(protocol);
    }

    /**
     * @notice Internal function to check if facet is allowed
     * @param facet Address to check
     * @return bool True if facet is allowed
     */
    function _isFacetAllowed(
        address facet
    ) internal view override returns (bool) {
        return _allowedFacets[facet];
    }
}

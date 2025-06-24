// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BaseVaultsRegistry, EnumerableSet} from "./BaseVaultsRegistry.sol";

/**
 * @title VaultsRegistry
 * @notice Registry contract that stores information about allowed facets and their selectors
 */
contract VaultsRegistry is BaseVaultsRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;

    error InvalidFee();
    error SelectorDidntExist(bytes4);
    error ArrayLengthMismatch();

    /// @dev Mapping of facet address => is allowed
    mapping(address => bool) private _allowedFacets;

    uint96 private constant MAX_PROTOCOL_FEE = 5000; // 50%

    /**
     * @inheritdoc IMoreVaultsRegistry
     */
    function isPermissionless() external pure override returns (bool) {
        return false;
    }

    /**
     * @inheritdoc IMoreVaultsRegistry
     */
    function addFacet(
        address facet,
        bytes4[] calldata selectors
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (facet == address(0)) revert ZeroAddress();

        if (!_allowedFacets[facet]) {
            _allowedFacets[facet] = true;
            _facetsList.add(facet);
        }

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
    function editFacet(
        address facet,
        bytes4[] calldata selectors,
        bool[] calldata addOrRemove
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (facet == address(0)) revert ZeroAddress();
        if (!_allowedFacets[facet]) revert FacetNotAllowed(facet);
        if (selectors.length != addOrRemove.length)
            revert ArrayLengthMismatch();

        for (uint i = 0; i < selectors.length; ) {
            bytes4 selector = selectors[i];
            if (addOrRemove[i]) {
                if (selectorToFacet[selector] != address(0))
                    revert SelectorAlreadyExists(
                        selectorToFacet[selector],
                        selector
                    );

                selectorToFacet[selector] = facet;
                facetSelectors[facet].push(selector);
            } else {
                if (selectorToFacet[selector] == address(0))
                    revert SelectorDidntExist(selector);
                selectorToFacet[selector] = address(0);

                bytes4[] storage _facetSelectorsArray = facetSelectors[facet];
                for (uint j = 0; j < _facetSelectorsArray.length; ) {
                    if (_facetSelectorsArray[j] == selector) {
                        _facetSelectorsArray[j] = _facetSelectorsArray[
                            _facetSelectorsArray.length - 1
                        ];
                        _facetSelectorsArray.pop();
                        break;
                    }
                    unchecked {
                        ++j;
                    }
                }
            }

            unchecked {
                ++i;
            }
        }
        if (facetSelectors[facet].length == 0) {
            _allowedFacets[facet] = false;
            _facetsList.remove(facet);
        }

        emit FacetEdited(facet, selectors, addOrRemove);
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
        _facetsList.remove(facet);

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

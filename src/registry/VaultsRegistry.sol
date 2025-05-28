// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BaseVaultsRegistry} from "./BaseVaultsRegistry.sol";

/**
 * @title VaultsRegistry
 * @notice Registry contract that stores information about allowed facets and their selectors
 */
contract VaultsRegistry is BaseVaultsRegistry {
    error InvalidFee();

    /// @dev Mapping of facet address => is allowed
    mapping(address => bool) private _allowedFacets;

    uint96 private constant MAX_PROTOCOL_FEE = 5000; // 50%

    /**
     * @notice Add new facet with its selectors or additional selector for existing facet
     * @param facet Address of the facet contract
     * @param selectors Array of function selectors
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
     * @notice Remove facet and all its selectors
     * @param facet Address of the facet contract
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
     * @notice Set protocol fee info
     * @param vault The address of the vault
     * @param recipient The address of the recipient
     * @param fee The fee
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
     * @notice Get protocol fee info
     * @param vault The address of the vault
     * @return recipient The address of the recipient
     * @return fee The fee
     */
    function protocolFeeInfo(
        address vault
    ) external view override returns (address, uint96) {
        return (_protocolFeeInfo[vault].recipient, _protocolFeeInfo[vault].fee);
    }

    function _isFacetAllowed(
        address facet
    ) internal view override returns (bool) {
        return _allowedFacets[facet];
    }
}

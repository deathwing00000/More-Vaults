// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAaveOracle} from "@aave-v3-core/contracts/interfaces/IAaveOracle.sol";

/**
 * @title IVaultRegistry
 * @notice Interface for VaultRegistry contract that manages allowed facets and their selectors
 */
interface IMoreVaultsRegistry {
    error ZeroAddress();
    error FacetAlreadyExists(address facet);
    error FacetNotAllowed(address facet);
    error SelectorAlreadyExists(address facet, bytes4 selector);

    struct ProtocolFeeInfo {
        address recipient;
        uint96 fee;
    }

    /**
     * @dev Emitted when new facet is added with its selectors
     * @param facet Address of added facet
     * @param selectors Array of function selectors
     */
    event FacetAdded(address indexed facet, bytes4[] selectors);

    /**
     * @dev Emitted when facet is removed
     * @param facet Address of removed facet
     */
    event FacetRemoved(address indexed facet);

    /**
     * @dev Emitted when oracle address is updated
     * @param oldOracle Previous oracle address
     * @param newOracle New oracle address
     */
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    /**
     * @dev Emitted when protocol fee info is updated
     * @param vault Address of the vault
     * @param recipient Address of the protocol fee recipient
     * @param fee Protocol fee
     */
    event ProtocolFeeInfoUpdated(
        address indexed vault,
        address indexed recipient,
        uint96 fee
    );

    /**
     * @notice Initialize the registry
     * @param _oracle Address of the oracle
     * @param _usdStableTokenAddress Address of the USD stable token
     */
    function initialize(
        address _oracle,
        address _usdStableTokenAddress
    ) external;

    /**
     * @notice Add new facet with its selectors
     * @param facet Address of the facet contract
     * @param selectors Array of function selectors
     */
    function addFacet(address facet, bytes4[] calldata selectors) external;

    /**
     * @notice Remove facet and all its selectors
     * @param facet Address of the facet contract
     */
    function removeFacet(address facet) external;

    /**
     * @notice Update oracle address
     * @param newOracle Address of new oracle
     */
    function updateOracle(address newOracle) external;

    /**
     * @notice Set protocol fee info
     * @param vault Address of the vault
     * @param recipient Address of the protocol fee recipient
     * @param fee Protocol fee
     */
    function setProtocolFeeInfo(
        address vault,
        address recipient,
        uint96 fee
    ) external;

    /**
     * @notice Get all selectors for facet
     * @param facet Address of the facet contract
     * @return Array of selectors
     */
    function getFacetSelectors(
        address facet
    ) external view returns (bytes4[] memory);

    /**
     * @notice Get list of all allowed facets
     * @return Array of facet addresses
     */
    function getAllowedFacets() external view returns (address[] memory);

    /**
     * @notice Get protocol fee info
     * @param vault Address of the vault
     * @return address Address of the protocol fee recipient
     * @return uint96 Protocol fee
     */
    function protocolFeeInfo(
        address vault
    ) external view returns (address, uint96);

    /**
     * @notice Get oracle address
     * @return IAaveOracle Oracle contract
     */
    function oracle() external view returns (IAaveOracle);

    /**
     * @notice Get facet address for selector
     * @param selector Function selector
     * @return address Facet address
     */
    function selectorToFacet(bytes4 selector) external view returns (address);

    /**
     * @notice Get facet address by index
     * @param index Index in facets list
     * @return address Facet address
     */
    function facetsList(uint256 index) external view returns (address);

    /**
     * @notice Get denomination asset decimals
     * @return uint8 Decimals of denomination asset
     */
    function getDenominationAssetDecimals() external view returns (uint8);

    /**
     * @notice Get denomination asset
     * @return address Denomination asset
     */
    function getDenominationAsset() external view returns (address);

    /**
     * @notice Check if facet is allowed
     * @param facet Address to check
     * @return bool True if facet is allowed
     */
    function isFacetAllowed(address facet) external view returns (bool);
}

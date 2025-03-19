// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAaveOracle} from "@aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title BaseVaultsRegistry
 * @notice Base registry contract that stores information about allowed facets and their selectors
 */
abstract contract BaseVaultsRegistry is IMoreVaultsRegistry, AccessControl {
    /// @dev Aave price oracle address
    IAaveOracle public oracle;

    /// @dev Mapping selector => facet address (показывает какому фасету принадлежит селектор)
    mapping(bytes4 => address) public selectorToFacet;

    /// @dev Mapping of facet address => all selectors
    mapping(address => bytes4[]) public facetSelectors;

    /// @dev List of all allowed facets
    address[] public facetsList;

    /// @dev USDC token address
    address public immutable usdcAddress;

    constructor(address _oracle, address _usdcAddress) {
        if (_oracle == address(0)) revert ZeroAddress();

        oracle = IAaveOracle(_oracle);
        usdcAddress = _usdcAddress;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Update oracle address
     * @param newOracle Address of new oracle
     */
    function updateOracle(
        address newOracle
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newOracle == address(0)) revert ZeroAddress();

        address oldOracle = address(oracle);
        oracle = IAaveOracle(newOracle);

        emit OracleUpdated(oldOracle, newOracle);
    }

    /**
     * @notice Get all selectors for facet
     * @param facet Address of the facet contract
     * @return bytes4[] Array of selectors
     */
    function getFacetSelectors(
        address facet
    ) external view returns (bytes4[] memory) {
        return facetSelectors[facet];
    }

    /**
     * @notice Get list of all allowed facets
     * @return address[] Array of facet addresses
     */
    function getAllowedFacets() external view returns (address[] memory) {
        return facetsList;
    }

    function getDenominationAsset() external view returns (address) {
        if (oracle.BASE_CURRENCY() == address(0)) return usdcAddress;
        return oracle.BASE_CURRENCY();
    }

    function getDenominationAssetDecimals() external view returns (uint8) {
        address denominationAsset = oracle.BASE_CURRENCY();
        if (denominationAsset == address(0))
            return IERC20Metadata(usdcAddress).decimals();
        else return IERC20Metadata(denominationAsset).decimals();
    }

    /**
     * @notice Check if facet is allowed
     * @param facet Address to check
     * @return bool True if facet is allowed
     */
    function isFacetAllowed(address facet) external view returns (bool) {
        return _isFacetAllowed(facet);
    }

    /**
     * @notice Internal function to check if facet is allowed
     * @param facet Address to check
     * @return bool True if facet is allowed
     */
    function _isFacetAllowed(
        address facet
    ) internal view virtual returns (bool);

    /**
     * @notice Add new facet with its selectors
     * @param facet Address of the facet contract
     * @param selectors Array of function selectors
     */
    function addFacet(
        address facet,
        bytes4[] calldata selectors
    ) external virtual;

    /**
     * @notice Remove facet and all its selectors
     * @param facet Address of the facet contract
     */
    function removeFacet(address facet) external virtual;
}

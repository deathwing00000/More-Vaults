// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IAaveOracle} from "@aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title BaseVaultsRegistry
 * @notice Base registry contract that stores information about allowed facets and their selectors
 */
abstract contract BaseVaultsRegistry is
    IMoreVaultsRegistry,
    AccessControlUpgradeable
{
    /// @dev Aave price oracle address
    IAaveOracle public oracle;

    /// @dev Mapping selector => facet address (показывает какому фасету принадлежит селектор)
    mapping(bytes4 => address) public selectorToFacet;

    /// @dev Mapping of facet address => all selectors
    mapping(address => bytes4[]) public facetSelectors;

    /// @dev List of all allowed facets
    address[] public facetsList;

    /// @dev USD stable token address
    address public usdStableTokenAddress;

    /// @dev Protocol fee info
    mapping(address => ProtocolFeeInfo) internal _protocolFeeInfo;

    /// @dev Initialize function
    function initialize(
        address _oracle,
        address _usdStableTokenAddress
    ) external virtual initializer {
        if (_oracle == address(0)) revert ZeroAddress();

        __AccessControl_init();
        oracle = IAaveOracle(_oracle);
        usdStableTokenAddress = _usdStableTokenAddress;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function updateOracle(
        address newOracle
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newOracle == address(0)) revert ZeroAddress();

        address oldOracle = address(oracle);
        oracle = IAaveOracle(newOracle);

        emit OracleUpdated(oldOracle, newOracle);
    }

    function setProtocolFeeInfo(
        address vault,
        address recipient,
        uint96 fee
    ) external virtual;

    function getFacetSelectors(
        address facet
    ) external view returns (bytes4[] memory) {
        return facetSelectors[facet];
    }

    function getAllowedFacets() external view returns (address[] memory) {
        return facetsList;
    }

    function protocolFeeInfo(
        address vault
    ) external view virtual returns (address, uint96);

    function getDenominationAsset() external view returns (address) {
        if (oracle.BASE_CURRENCY() == address(0)) return usdStableTokenAddress;
        return oracle.BASE_CURRENCY();
    }

    function getDenominationAssetDecimals() external view returns (uint8) {
        address denominationAsset = oracle.BASE_CURRENCY();
        if (denominationAsset == address(0))
            return IERC20Metadata(usdStableTokenAddress).decimals();
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

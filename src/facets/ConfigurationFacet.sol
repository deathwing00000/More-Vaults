// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {IConfigurationFacet} from "../interfaces/facets/IConfigurationFacet.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";

contract ConfigurationFacet is BaseFacetInitializer, IConfigurationFacet {
    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.ConfigurationFacet");
    }

    function facetName() external pure returns (string memory) {
        return "ConfigurationFacet";
    }

    function initialize(bytes calldata) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.supportedInterfaces[type(IConfigurationFacet).interfaceId] = true;
    }

    /**
     * @notice Sets fee recipient address
     * @param recipient New fee recipient address
     */
    function setFeeRecipient(address recipient) external {
        AccessControlLib.validateOwner(msg.sender);
        MoreVaultsLib._setFeeRecipient(recipient);
    }

    /**
     * @notice Sets fee amount
     * @param fee New fee amount
     */
    function setFee(uint96 fee) external {
        AccessControlLib.validateOwner(msg.sender);
        MoreVaultsLib._setFee(fee);
    }

    /**
     * @notice Sets time lock period
     * @param period New time lock period
     */
    function setTimeLockPeriod(uint256 period) external {
        AccessControlLib.validateOwner(msg.sender);
        MoreVaultsLib._setTimeLockPeriod(period);
    }

    /**
     * @notice Adds new available asset to manage
     * @param asset Asset address to add
     */
    function addAvailableAsset(address asset) external {
        AccessControlLib.validateCurator(msg.sender);
        MoreVaultsLib._addAvailableAsset(asset);
    }

    /**
     * @notice Batch adds new available assets to manage
     * @param assets Array of asset addresses to add
     */
    function addAvailableAssets(address[] calldata assets) external {
        AccessControlLib.validateCurator(msg.sender);

        for (uint256 i = 0; i < assets.length; ) {
            MoreVaultsLib._addAvailableAsset(assets[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Enables asset to deposit
     * @param asset Asset address to enable
     */
    function enableAssetToDeposit(address asset) external {
        AccessControlLib.validateCurator(msg.sender);
        MoreVaultsLib._enableAssetToDeposit(asset);
    }

    /**
     * @notice Disables asset to deposit
     * @param asset Asset address to disable
     */
    function disableAssetToDeposit(address asset) external {
        AccessControlLib.validateCurator(msg.sender);
        MoreVaultsLib._disableAssetToDeposit(asset);
    }

    /**
     * @notice Checks if asset is depositable
     * @param asset Asset address to check
     * @return true if asset is depositable
     */
    function isAssetDepositable(address asset) external view returns (bool) {
        return MoreVaultsLib.moreVaultsStorage().isAssetDepositable[asset];
    }

    /**
     * @notice Checks if asset is available
     * @param asset Asset address to check
     * @return true if asset is available
     */
    function isAssetAvailable(address asset) external view returns (bool) {
        return MoreVaultsLib.moreVaultsStorage().isAssetAvailable[asset];
    }

    /**
     * @notice Gets list of all available assets
     * @return Array of available asset addresses
     */
    function getAvailableAssets() external view returns (address[] memory) {
        return MoreVaultsLib.moreVaultsStorage().availableAssets;
    }
}

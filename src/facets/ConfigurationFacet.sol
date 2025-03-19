// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {IConfigurationFacet} from "../interfaces/facets/IConfigurationFacet.sol";

contract ConfigurationFacet is IConfigurationFacet {
    function facetName() external pure returns (string memory) {
        return "ConfigurationFacet";
    }

    /**
     * @notice Sets fee recipient address
     * @param recipient New fee recipient address
     */
    function setFeeRecipient(address recipient) external {
        AccessControlLib.validateCurator(msg.sender);
        if (recipient == address(0)) {
            revert InvalidAddress();
        }

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address previousRecipient = ds.feeRecipient;
        ds.feeRecipient = recipient;

        emit FeeRecipientSet(previousRecipient, recipient);
    }

    /**
     * @notice Sets fee amount
     * @param fee New fee amount
     */
    function setFee(uint96 fee) external {
        AccessControlLib.validateCurator(msg.sender);
        if (fee > 10000) {
            // Max 100% (10000 basis points)
            revert InvalidFee();
        }

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        uint96 previousFee = ds.fee;
        ds.fee = fee;

        emit FeeSet(previousFee, fee);
    }

    /**
     * @notice Sets time lock period
     * @param period New time lock period
     */
    function setTimeLockPeriod(uint256 period) external {
        AccessControlLib.validateCurator(msg.sender);
        if (period == 0) {
            revert InvalidPeriod();
        }

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        uint256 previousPeriod = ds.timeLockPeriod;
        ds.timeLockPeriod = period;

        emit TimeLockPeriodSet(previousPeriod, period);
    }

    /**
     * @notice Adds new available asset
     * @param asset Asset address to add
     */
    function addAvailableAsset(address asset) external {
        AccessControlLib.validateCurator(msg.sender);
        if (asset == address(0)) {
            revert InvalidAddress();
        }

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        if (ds.isAssetAvailable[asset]) {
            revert AssetAlreadyAvailable();
        }

        ds.isAssetAvailable[asset] = true;
        ds.availableAssets.push(asset);

        emit AssetAdded(asset);
    }

    /**
     * @notice Batch adds new available assets
     * @param assets Array of asset addresses to add
     */
    function addAvailableAssets(address[] calldata assets) external {
        AccessControlLib.validateCurator(msg.sender);

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            if (asset == address(0)) {
                revert InvalidAddress();
            }
            if (!ds.isAssetAvailable[asset]) {
                ds.isAssetAvailable[asset] = true;
                ds.availableAssets.push(asset);
                emit AssetAdded(asset);
            }
        }
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

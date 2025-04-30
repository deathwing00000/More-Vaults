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
     * @inheritdoc IConfigurationFacet
     */
    function setFeeRecipient(address recipient) external {
        AccessControlLib.validateOwner(msg.sender);
        MoreVaultsLib._setFeeRecipient(recipient);
    }

    /**
     * @inheritdoc IConfigurationFacet
     */
    function setFee(uint96 _fee) external {
        AccessControlLib.validateOwner(msg.sender);
        MoreVaultsLib._setFee(_fee);
    }

    /**
     * @inheritdoc IConfigurationFacet
     */
    function setDepositCapacity(uint256 capacity) external {
        AccessControlLib.validateCurator(msg.sender);
        MoreVaultsLib._setDepositCapacity(capacity);
    }

    /**
     * @inheritdoc IConfigurationFacet
     */
    function setTimeLockPeriod(uint256 period) external {
        AccessControlLib.validateOwner(msg.sender);
        MoreVaultsLib._setTimeLockPeriod(period);
    }

    /**
     * @inheritdoc IConfigurationFacet
     */
    function addAvailableAsset(address asset) external {
        AccessControlLib.validateCurator(msg.sender);
        MoreVaultsLib._addAvailableAsset(asset);
    }

    /**
     * @inheritdoc IConfigurationFacet
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
     * @inheritdoc IConfigurationFacet
     */
    function enableAssetToDeposit(address asset) external {
        AccessControlLib.validateCurator(msg.sender);
        MoreVaultsLib._enableAssetToDeposit(asset);
    }

    /**
     * @inheritdoc IConfigurationFacet
     */
    function disableAssetToDeposit(address asset) external {
        AccessControlLib.validateCurator(msg.sender);
        MoreVaultsLib._disableAssetToDeposit(asset);
    }

    /**
     * @inheritdoc IConfigurationFacet
     */
    function isAssetDepositable(address asset) external view returns (bool) {
        return MoreVaultsLib.moreVaultsStorage().isAssetDepositable[asset];
    }

    /**
     * @inheritdoc IConfigurationFacet
     */
    function isAssetAvailable(address asset) external view returns (bool) {
        return MoreVaultsLib.moreVaultsStorage().isAssetAvailable[asset];
    }

    /**
     * @inheritdoc IConfigurationFacet
     */
    function getAvailableAssets() external view returns (address[] memory) {
        return MoreVaultsLib.moreVaultsStorage().availableAssets;
    }

    /**
     * @inheritdoc IConfigurationFacet
     */
    function fee() external view returns (uint96) {
        return MoreVaultsLib.moreVaultsStorage().fee;
    }

    /**
     * @inheritdoc IConfigurationFacet
     */
    function feeRecipient() external view returns (address) {
        return MoreVaultsLib.moreVaultsStorage().feeRecipient;
    }

    /**
     * @inheritdoc IConfigurationFacet
     */
    function depositCapacity() external view returns (uint256) {
        return MoreVaultsLib.moreVaultsStorage().depositCapacity;
    }

    /**
     * @inheritdoc IConfigurationFacet
     */
    function timeLockPeriod() external view returns (uint256) {
        return MoreVaultsLib.moreVaultsStorage().timeLockPeriod;
    }
}

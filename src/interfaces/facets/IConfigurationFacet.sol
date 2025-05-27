// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";

interface IConfigurationFacet is IGenericMoreVaultFacetInitializable {
    /**
     * @dev Custom errors
     */
    error InvalidAddress();
    error InvalidPeriod();
    error AssetAlreadyAvailable();
    error AssetNotAvailable();
    error TimeLockPeriodNotExpired();
    error NothingSubmitted();

    /**
     * @dev Events
     */
    /// @notice Emitted when the MoreVaults registry is set
    event MoreVaultRegistrySet(
        address indexed previousRegistry,
        address indexed newRegistry
    );
    /// @notice Emitted when a new asset is added
    event AssetAdded(address indexed asset);
    /// @notice Emitted when an asset is removed
    event AssetRemoved(address indexed asset);

    /**
     * @notice Sets fee recipient address
     * @param recipient New fee recipient address
     */
    function setFeeRecipient(address recipient) external;

    /**
     * @notice Sets time lock period
     * @param period New time lock period (in seconds)
     */
    function setTimeLockPeriod(uint256 period) external;

    /**
     * @notice Sets deposit capacity
     * @param capacity New deposit capacity
     */
    function setDepositCapacity(uint256 capacity) external;

    /**
     * @notice Adds new available asset
     * @param asset Asset address to add
     */
    function addAvailableAsset(address asset) external;

    /**
     * @notice Batch adds new available assets
     * @param assets Array of asset addresses to add
     */
    function addAvailableAssets(address[] calldata assets) external;

    /**
     * @notice Enables asset to deposit
     * @param asset Asset address to enable
     */
    function enableAssetToDeposit(address asset) external;

    /**
     * @notice Disables asset to deposit
     * @param asset Asset address to disable
     */
    function disableAssetToDeposit(address asset) external;

    /**
     * @notice Checks if asset is available
     * @param asset Asset address to check
     * @return true if asset is available
     */
    function isAssetAvailable(address asset) external view returns (bool);

    /**
     * @notice Checks if asset is depositable
     * @param asset Asset address to check
     * @return true if asset is depositable
     */
    function isAssetDepositable(address asset) external view returns (bool);

    /**
     * @notice Gets list of all available assets
     * @return Array of available asset addresses
     */
    function getAvailableAssets() external view returns (address[] memory);

    /**
     * @notice Gets fee amount
     * @return Fee amount
     */
    function fee() external view returns (uint96);

    /**
     * @notice Gets fee recipient address
     * @return Fee recipient address
     */
    function feeRecipient() external view returns (address);

    /**
     * @notice Gets deposit capacity
     * @return Deposit capacity
     */
    function depositCapacity() external view returns (uint256);

    /**
     * @notice Gets time lock period
     * @return Time lock period
     */
    function timeLockPeriod() external view returns (uint256);
}

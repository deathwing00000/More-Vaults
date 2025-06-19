// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";

interface IVaultFacet is IERC4626, IGenericMoreVaultFacetInitializable {
    /// @dev Errors
    error AccountingFailed(address facet);
    error BeforeAccountingFailed(address facet);
    error UnsupportedAsset(address);
    error ArraysLengthsDontMatch(uint256, uint256);
    error WithdrawFailed(string);
    error VaultDebtIsGreaterThanAssets();

    /// @dev Events
    event Deposit(
        address indexed sender,
        address indexed owner,
        address[] tokens,
        uint256[] assets,
        uint256 shares
    );

    event AccrueInterest(uint256 newTotalAssets, uint256 interestAccrued);

    event WithdrawalTimelockSet(uint64 duration);

    /// @notice Pauses all vault operations
    function pause() external;

    /// @notice Unpauses all vault operations
    function unpause() external;

    /// @notice Returns whether the contract is paused
    function paused() external view returns (bool);

    /// @notice Returns the total amount of the underlying asset that is "managed" by Vault
    function totalAssets() external view override returns (uint256);

    /// @notice Returns the request for a given owner
    /// @param _owner The owner of the request
    /// @return shares The shares of the request
    /// @return timelockEndsAt The timelock end time of the request
    function getWithdrawalRequest(
        address _owner
    ) external view returns (uint256 shares, uint256 timelockEndsAt);

    /// @notice Returns the withdrawal timelock duration
    /// @return duration The withdrawal timelock duration
    function getWithdrawalTimelock() external view returns (uint64);

    /// @notice Allows deposit of multiple tokens in a single transaction
    /// @param tokens Array of token addresses to deposit
    /// @param assets Array of amounts to deposit for each token
    /// @param receiver Address that will receive the vault shares
    /// @return shares Amount of vault shares minted
    function deposit(
        address[] calldata tokens,
        uint256[] calldata assets,
        address receiver
    ) external payable returns (uint256 shares);

    /// @notice Deposit a single asset for shares
    /// @param assets Amount of asset to deposit
    /// @param receiver Address that will receive the vault shares
    /// @return shares Amount of vault shares minted
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);

    /// @notice Mint exact amount of shares by depositing assets
    /// @param shares Amount of shares to mint
    /// @param receiver Address that will receive the vault shares
    /// @return assets Amount of assets deposited
    function mint(
        uint256 shares,
        address receiver
    ) external returns (uint256 assets);

    /// @notice Withdraw assets by burning shares
    /// @param assets Amount of assets to withdraw
    /// @param receiver Address that will receive the assets
    /// @param owner Owner of the shares
    /// @return shares Amount of shares burned
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    /// @notice Redeem shares for assets
    /// @param shares Amount of shares to redeem
    /// @param receiver Address that will receive the assets
    /// @param owner Owner of the shares
    /// @return assets Amount of assets withdrawn
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    /**
     * @notice Sets fee amount
     * @param fee New fee amount (in basis points, max 10000 = 100%)
     */
    function setFee(uint96 fee) external;

    /**
     * @notice Request a redeem of shares
     * @param shares Amount of shares to redeem
     */
    function requestRedeem(uint256 shares) external;

    /**
     * @notice Request a withdraw of assets
     * @param assets Amount of assets to withdraw
     */
    function requestWithdraw(uint256 assets) external;

    /**
     * @notice Clear a request
     */
    function clearRequest() external;

    /**
     * @notice Update the withdraw timelock duration
     * @param duration New withdraw timelock duration
     */
    function setWithdrawalTimelock(uint64 duration) external;
}

pragma solidity 0.8.28;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Original interface: Origami (interfaces/investments/lovToken/managers/IOrigamiLovTokenFlashAndBorrowManager.sol)

/**
 * @title Origami lovToken Manager
 * @notice The delegated logic to handle deposits/exits, and borrow/repay (rebalances) into the underlying reserve token
 */
interface IOrigamiLovTokenFlashAndBorrowManager {
    struct RebalanceUpParams {
        // The amount of `debtToken` to flashloan, used to repay Aave/Spark debt
        uint256 flashLoanAmount;
        // The amount of `reserveToken` collateral to withdraw after debt is repaid
        uint256 collateralToWithdraw;
        // The swap quote data to swap from `reserveToken` -> `debtToken`
        bytes swapData;
        // The min balance threshold for when surplus balance of `debtToken` is repaid to the Spark/Aave position
        uint256 repaySurplusThreshold;
        // The minimum acceptable A/L, will revert if below this
        uint128 minNewAL;
        // The maximum acceptable A/L, will revert if above this
        uint128 maxNewAL;
    }

    /**
     * @notice Increase the A/L by reducing liabilities. Flash loan and repay debt, and withdraw collateral to repay the flash loan
     */
    function rebalanceUp(RebalanceUpParams calldata params) external;

    /**
     * @notice Force a rebalanceUp ignoring A/L ceiling/floor
     * @dev Separate function to above to have stricter control on who can force
     */
    function forceRebalanceUp(RebalanceUpParams calldata params) external;

    struct RebalanceDownParams {
        // The amount of new `debtToken` to flashloan
        uint256 flashLoanAmount;
        // The minimum amount of `reserveToken` expected when swapping from the flashloaned amount
        uint256 minExpectedReserveToken;
        // The swap quote data to swap from `debtToken` -> `reserveToken`
        bytes swapData;
        // The minimum acceptable A/L, will revert if below this
        uint128 minNewAL;
        // The maximum acceptable A/L, will revert if above this
        uint128 maxNewAL;
    }

    /**
     * @notice Decrease the A/L by increasing liabilities. Flash loan `debtToken` swap to `reserveToken`
     * and add as collateral into Aave/Spark. Then borrow `debtToken` to repay the flash loan.
     */
    function rebalanceDown(RebalanceDownParams calldata params) external;

    /**
     * @notice Force a rebalanceDown ignoring A/L ceiling/floor
     * @dev Separate function to above to have stricter control on who can force
     */
    function forceRebalanceDown(RebalanceDownParams calldata params) external;
}

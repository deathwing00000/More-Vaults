// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IOrigamiInvestment} from "../Origami/IOrigamiInvestment.sol";
import {IOrigamiLovTokenFlashAndBorrowManager} from "../Origami/IOrigamiLovTokenFlashAndBorrowManager.sol";
import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";

interface IOrigamiFacet is IGenericMoreVaultFacetInitializable {
    error UnsupportedAsset(address);
    error UnsupportedLovToken(address);

    function facetName() external pure returns (string memory);

    function accountingOrigamiFacet() external view returns (uint sum);

    /**
     * @notice Invests with a token
     * @param lovToken The address of the lov token
     * @param quoteData The quote data
     * @return investmentAmount The amount of the investment
     */
    function investWithToken(
        address lovToken,
        IOrigamiInvestment.InvestQuoteData calldata quoteData
    ) external returns (uint256 investmentAmount);

    /**
     * @notice Invests with native
     * @param lovToken The address of the lov token
     * @param quoteData The quote data
     * @return investmentAmount The amount of the investment
     */
    function investWithNative(
        address lovToken,
        IOrigamiInvestment.InvestQuoteData calldata quoteData
    ) external returns (uint256 investmentAmount);

    /**
     * @notice Exits to token
     * @param lovToken The address of the lov token
     * @param quoteData The quote data
     * @return toTokenAmount The amount of the exit
     */
    function exitToToken(
        address lovToken,
        IOrigamiInvestment.ExitQuoteData calldata quoteData
    ) external returns (uint256 toTokenAmount);

    /**
     * @notice Exits to native
     * @param lovToken The address of the lov token
     * @param quoteData The quote data
     * @return toTokenAmount The amount of the exit
     */
    function exitToNative(
        address lovToken,
        IOrigamiInvestment.ExitQuoteData calldata quoteData
    ) external returns (uint256 toTokenAmount);

    /**
     * @notice Rebalances up
     * @param manager The address of the manager
     * @param flashLoanAmount The amount of the flash loan
     * @param collateralToWithdraw The amount of the collateral to withdraw
     * @param swapData The swap data
     * @param repaySurplusThreshold The amount of the repay surplus threshold
     * @param minNewAL The minimum new al
     * @param maxNewAL The maximum new al
     */
    function rebalanceUp(
        address manager,
        uint256 flashLoanAmount,
        uint256 collateralToWithdraw,
        bytes calldata swapData,
        uint256 repaySurplusThreshold,
        uint128 minNewAL,
        uint128 maxNewAL
    ) external;

    /**
     * @notice Rebalances up, don't check max/min AL
     * @param manager The address of the manager
     * @param flashLoanAmount The amount of the flash loan
     * @param collateralToWithdraw The amount of the collateral to withdraw
     * @param swapData The swap data
     * @param repaySurplusThreshold The amount of the repay surplus threshold
     * @param minNewAL The minimum new al
     * @param maxNewAL The maximum new al
     */
    function forceRebalanceUp(
        address manager,
        uint256 flashLoanAmount,
        uint256 collateralToWithdraw,
        bytes calldata swapData,
        uint256 repaySurplusThreshold,
        uint128 minNewAL,
        uint128 maxNewAL
    ) external;

    /**
     * @notice Rebalances down
     * @param manager The address of the manager
     * @param flashLoanAmount The amount of the flash loan
     * @param minExpectedReserveToken The minimum expected reserve token
     * @param swapData The swap data
     * @param minNewAL The minimum new al
     * @param maxNewAL The maximum new al
     */
    function rebalanceDown(
        address manager,
        uint256 flashLoanAmount,
        uint256 minExpectedReserveToken,
        bytes calldata swapData,
        uint128 minNewAL,
        uint128 maxNewAL
    ) external;

    /**
     * @notice Rebalances down, don't check max/min AL
     * @param manager The address of the manager
     * @param flashLoanAmount The amount of the flash loan
     * @param minExpectedReserveToken The minimum expected reserve token
     * @param swapData The swap data
     * @param minNewAL The minimum new al
     * @param maxNewAL The maximum new al
     */
    function forceRebalanceDown(
        address manager,
        uint256 flashLoanAmount,
        uint256 minExpectedReserveToken,
        bytes calldata swapData,
        uint128 minNewAL,
        uint128 maxNewAL
    ) external;
}

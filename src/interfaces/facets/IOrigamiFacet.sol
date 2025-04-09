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

    function investWithToken(
        address lovToken,
        IOrigamiInvestment.InvestQuoteData calldata quoteData
    ) external returns (uint256 investmentAmount);

    function investWithNative(
        address lovToken,
        IOrigamiInvestment.InvestQuoteData calldata quoteData
    ) external returns (uint256 investmentAmount);

    function exitToToken(
        address lovToken,
        IOrigamiInvestment.ExitQuoteData calldata quoteData
    ) external returns (uint256 toTokenAmount);

    function exitToNative(
        address lovToken,
        IOrigamiInvestment.ExitQuoteData calldata quoteData
    ) external returns (uint256 toTokenAmount);

    function rebalanceUp(
        address manager,
        uint256 flashLoanAmount,
        uint256 collateralToWithdraw,
        bytes calldata swapData,
        uint256 repaySurplusThreshold,
        uint128 minNewAL,
        uint128 maxNewAL
    ) external;

    function forceRebalanceUp(
        address manager,
        uint256 flashLoanAmount,
        uint256 collateralToWithdraw,
        bytes calldata swapData,
        uint256 repaySurplusThreshold,
        uint128 minNewAL,
        uint128 maxNewAL
    ) external;

    function rebalanceDown(
        address manager,
        uint256 flashLoanAmount,
        uint256 minExpectedReserveToken,
        bytes calldata swapData,
        uint128 minNewAL,
        uint128 maxNewAL
    ) external;

    function forceRebalanceDown(
        address manager,
        uint256 flashLoanAmount,
        uint256 minExpectedReserveToken,
        bytes calldata swapData,
        uint128 minNewAL,
        uint128 maxNewAL
    ) external;
}

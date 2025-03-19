// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOrigamiInvestment} from "../Origami/IOrigamiInvestment.sol";
import {IOrigamiLovTokenFlashAndBorrowManager} from "../Origami/IOrigamiLovTokenFlashAndBorrowManager.sol";
import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";

interface IOrigamiFacet is IGenericMoreVaultFacetInitializable {
    error UnsupportedAsset(address);
    error UnsupportedLovToken(address);

    function facetName() external pure returns (string memory);

    // function withdrawFromOrigamiFacet(uint proportion, address to) external;

    function accountingOrigamiFacet() external view returns (uint sum);

    function investWithToken(
        address lovToken,
        uint256 fromTokenAmount,
        address fromToken,
        uint256 maxSlippageBps,
        uint256 deadline
    ) external returns (uint256 investmentAmount);

    function investWithNative(
        address lovToken,
        uint256 fromTokenAmount,
        address fromToken,
        uint256 maxSlippageBps,
        uint256 deadline
    ) external payable returns (uint256 investmentAmount);

    function exitToToken(
        address lovToken,
        uint256 investmentAmount,
        address toToken,
        uint256 maxSlippageBps,
        uint256 deadline
    ) external returns (uint256 toTokenAmount);

    function exitToNative(
        address lovToken,
        uint256 investmentAmount,
        address toToken,
        uint256 maxSlippageBps,
        uint256 deadline
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

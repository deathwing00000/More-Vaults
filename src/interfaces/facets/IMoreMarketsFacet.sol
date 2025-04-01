// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";

interface IMoreMarketsFacet is IGenericMoreVaultFacetInitializable {
    error UnsupportedAsset(address);
    error UnsupportedPool(address);

    function facetName() external pure returns (string memory);

    function accountingMoreMarketsFacet() external view returns (uint sum);

    function supply(
        address pool,
        address asset,
        uint256 amount,
        uint16 referralCode
    ) external;

    function withdraw(
        address pool,
        address asset,
        uint256 amount
    ) external returns (uint256 withdrawnAmount);

    function borrow(
        address pool,
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function repay(
        address pool,
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external returns (uint256 repaidAmount);

    function repayWithATokens(
        address pool,
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external returns (uint256 repaidAmount);

    function swapBorrowRateMode(
        address pool,
        address asset,
        uint256 interestRateMode
    ) external;

    function rebalanceStableBorrowRate(
        address pool,
        address asset,
        address user
    ) external;

    function setUserUseReserveAsCollateral(
        address pool,
        address asset,
        bool useAsCollateral
    ) external;

    function flashLoan(
        address pool,
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    function flashLoanSimple(
        address pool,
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;

    function setUserEMode(address pool, uint8 categoryId) external;

    function claimAllRewards(
        address rewardsController,
        address[] calldata assets
    )
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
}

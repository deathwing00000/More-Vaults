// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";

/// @title ICurveLiquidityGaugeV6Facet
interface ICurveLiquidityGaugeV6Facet is IGenericMoreVaultFacetInitializable {
    function beforeAccountingCurveLiquidityGaugeV6Facet() external;

    function accountingCurveLiquidityGaugeV6Facet()
        external
        view
        returns (uint256 sum, bool isPositive);

    /**
     * @notice deposits lp token into Curve's LiquidityGaugeV6 smart contract
     * all reward tokens should be set as available in the vault
     * @param gauge address of the gauge smart contract
     * @param amount of the lp token to deposit
     */
    function depositCurveGaugeV6(address gauge, uint256 amount) external;

    /**
     * @notice withdraws lp token from Curve's LiquidityGaugeV6 smart contract
     * @param gauge address of the gauge smart contract
     * @param amount of the lp token to withdraw
     */
    function withdrawCurveGaugeV6(address gauge, uint256 amount) external;

    /**
     * @notice collects all rewards from Curve's LiquidityGaugeV6 smart contract
     * all reward tokens should be set as available in the vault
     * @param gauge address of the gauge smart contract
     */
    function claimRewardsCurveGaugeV6(address gauge) external;

    /**
     * @notice claims crv rewards from Curve's Minter smart contract according to
     * Vault balance in Gauge.
     * all reward tokens should be set as available in the vault
     * @param minterContract address of Curve's Minter smart contract
     * @param gauge address of the gauge smart contract
     */
    function mintCRV(address minterContract, address gauge) external;
}

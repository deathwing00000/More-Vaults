// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IMultiRewards} from "../Curve/IMultiRewards.sol";
import {IGenericMoreVaultFacetInitializable} from "./IGenericMoreVaultFacetInitializable.sol";

interface IMultiRewardsFacet is IGenericMoreVaultFacetInitializable {
    function accountingMultiRewardsFacet() external returns (uint256);

    /**
     * @notice function that stakes tokens in the MultiRewards smart contract
     * reward tokens should be set as available in the vault.
     * @param staking address of the staking
     * @param amount of staked funds
     */
    function stake(address staking, uint256 amount) external;

    /**
     * @notice function that withdraws tokens from the MultiRewards smart contract
     * @param staking address of the staking
     * @param amount of funds to withdraw
     */
    function withdraw(address staking, uint256 amount) external;

    /**
     * @notice function that collects rewards from the staking
     * @param staking address of the staking
     */
    function getReward(address staking) external;

    /**
     * @notice function that performs withdraw of whole balance and collect rewards from the staking
     * @param staking address of the staking
     */
    function exit(address staking) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IMultiRewards} from "../Curve/IMultiRewards.sol";

interface IMultiRewardsFacet {
    function accountingMultiRewardsFacet() external returns (uint256);

    function stake(address staking, uint256 amount) external;

    function withdraw(address staking, uint256 amount) external;

    function getReward(address staking) external;

    function exit(address staking) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ILiquidityGaugeV6
interface ILiquidityGaugeV6 {
    function deposit(
        uint256 amount,
        address receiver,
        bool claimRewards
    ) external;

    function withdraw(uint256 amount, bool claimRewards) external;

    function claim_rewards(address owner, address receiver) external;

    function claimable_reward(
        address owner,
        address token
    ) external view returns (uint256);

    function lp_token() external view returns (address);

    function reward_count() external view returns (uint256);

    function reward_tokens(uint256 index) external view returns (address);

    function balanceOf(address account) external view returns (uint256);
}

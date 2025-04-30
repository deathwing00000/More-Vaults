// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMultiRewards {
    struct Reward {
        address rewardsDistributor;
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    event RewardAdded(
        address indexed rewardsToken,
        address indexed rewardsDistributor,
        uint256 indexed rewardsDuration
    );
    event RewardAmountNotified(address indexed reward, uint256 indexed amount);
    event Staked(address indexed user, uint256 indexed amount);
    event Withdrawn(address indexed user, uint256 indexed amount);
    event RewardPaid(
        address indexed user,
        address indexed rewardsToken,
        uint256 indexed reward
    );
    event RewardsDurationUpdated(
        address indexed token,
        uint256 indexed newDuration
    );
    event Recovered(address indexed token, uint256 indexed amount);

    function rewardData(
        address _rewardToken
    )
        external
        view
        returns (
            address rewardsDistributor,
            uint256 rewardsDuration,
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        );

    function stakingToken() external view returns (IERC20);

    function getRewardTokens() external view returns (address[] memory);

    function userRewardPerTokenPaid(
        address _user,
        address _rewardToken
    ) external view returns (uint256 _amount);

    function rewards(
        address _user,
        address _rewardToken
    ) external view returns (uint256 _amount);

    function addReward(
        address _rewardsToken,
        address _rewardsDistributor,
        uint256 _rewardsDuration
    ) external;

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function lastTimeRewardApplicable(
        address _rewardsToken
    ) external view returns (uint256);

    function rewardPerToken(
        address _rewardsToken
    ) external view returns (uint256);

    function earned(
        address account,
        address _rewardsToken
    ) external view returns (uint256);

    function getRewardForDuration(
        address _rewardsToken
    ) external view returns (uint256);

    function setRewardsDistributor(
        address _rewardsToken,
        address _rewardsDistributor
    ) external;

    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getReward() external;

    function exit() external;

    function notifyRewardAmount(address _rewardsToken, uint256 reward) external;

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external;

    function setRewardsDuration(
        address _rewardsToken,
        uint256 _rewardsDuration
    ) external;
}

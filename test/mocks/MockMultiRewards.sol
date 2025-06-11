// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
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

contract MockMultiRewards is IMultiRewards, ReentrancyGuard, Pausable, Ownable {
    using Math for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public immutable stakingToken;
    // slither-disable-next-line reentrancy-no-eth
    mapping(address => Reward) public override rewardData;
    address[] public rewardTokens;

    // user -> reward token -> amount
    mapping(address => mapping(address => uint256))
        public
        override userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public override rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _owner, address _stakingToken) Ownable(_owner) {
        stakingToken = IERC20(_stakingToken);
    }

    function addReward(
        address _rewardsToken,
        address _rewardsDistributor,
        uint256 _rewardsDuration
    ) external onlyOwner {
        require(
            rewardData[_rewardsToken].rewardsDuration == 0,
            "Reward already exists"
        );
        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;

        emit RewardAdded(_rewardsToken, _rewardsDistributor, _rewardsDuration);
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable(
        address _rewardsToken
    ) public view returns (uint256) {
        return
            Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    function rewardPerToken(
        address _rewardsToken
    ) public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardData[_rewardsToken].rewardPerTokenStored;
        }

        return
            rewardData[_rewardsToken].rewardPerTokenStored +
            (((lastTimeRewardApplicable(_rewardsToken) -
                rewardData[_rewardsToken].lastUpdateTime) *
                rewardData[_rewardsToken].rewardRate *
                1e18) / _totalSupply);
    }

    function earned(
        address account,
        address _rewardsToken
    ) public view returns (uint256) {
        return
            (_balances[account] *
                (rewardPerToken(_rewardsToken) -
                    (userRewardPerTokenPaid[account][_rewardsToken]))) /
            (1e18) +
            (rewards[account][_rewardsToken]);
    }

    function getRewardForDuration(
        address _rewardsToken
    ) external view returns (uint256) {
        return
            rewardData[_rewardsToken].rewardRate *
            (rewardData[_rewardsToken].rewardsDuration);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function setRewardsDistributor(
        address _rewardsToken,
        address _rewardsDistributor
    ) external onlyOwner {
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
    }

    function stake(
        uint256 amount
    ) external nonReentrant whenNotPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply + (amount);
        _balances[msg.sender] = _balances[msg.sender] + (amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(
        uint256 amount
    ) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply - (amount);
        _balances[msg.sender] = _balances[msg.sender] - (amount);
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    // slither-disable-next-line reentrancy-no-eth
    function getReward() public nonReentrant updateReward(msg.sender) {
        for (uint i; i < rewardTokens.length; i++) {
            address _rewardsToken = rewardTokens[i];
            uint256 reward = rewards[msg.sender][_rewardsToken];
            if (reward > 0) {
                rewards[msg.sender][_rewardsToken] = 0;
                IERC20(_rewardsToken).safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, _rewardsToken, reward);
            }
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // slither-disable-start reentrancy-events
    // slither-disable-next-line reentrancy-no-eth
    function notifyRewardAmount(
        address _rewardsToken,
        uint256 reward
    ) external updateReward(address(0)) {
        require(
            rewardData[_rewardsToken].rewardsDistributor == msg.sender,
            "!No rewards distributor"
        );
        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the reward amount
        IERC20(_rewardsToken).safeTransferFrom(
            msg.sender,
            address(this),
            reward
        );
        // slither-disable-next-line timestamp
        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            rewardData[_rewardsToken].rewardRate =
                reward /
                (rewardData[_rewardsToken].rewardsDuration);
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish -
                (block.timestamp);
            uint256 leftover = remaining *
                (rewardData[_rewardsToken].rewardRate);
            rewardData[_rewardsToken].rewardRate =
                reward +
                (leftover) /
                (rewardData[_rewardsToken].rewardsDuration);
        }

        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish =
            block.timestamp +
            (rewardData[_rewardsToken].rewardsDuration);
        emit RewardAmountNotified(_rewardsToken, reward);
    }
    // slither-disable-end reentrancy-events

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    // slither-disable-next-line reentrancy-events
    function recoverERC20(
        address tokenAddress,
        uint256 tokenAmount
    ) external onlyOwner {
        require(
            tokenAddress != address(stakingToken),
            "Cannot withdraw staking token"
        );
        require(
            rewardData[tokenAddress].lastUpdateTime == 0,
            "Cannot withdraw reward token"
        );
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    // Added to support recovering reward token in case nobody staked tokens.
    // slither-disable-next-line reentrancy-events
    function recoverRewardToken(
        address tokenAddress,
        uint256 tokenAmount
    ) external onlyOwner {
        require(
            tokenAddress != address(stakingToken),
            "Cannot withdraw staking token"
        );
        require(
            block.timestamp > rewardData[tokenAddress].periodFinish,
            "Cannot withdraw reward token"
        );
        require(tokenAmount > 0, "Cannot withdraw 0 reward token");
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setRewardsDuration(
        address _rewardsToken,
        uint256 _rewardsDuration
    ) external {
        // slither-disable-next-line timestamp
        require(
            block.timestamp > rewardData[_rewardsToken].periodFinish,
            "Reward period still active"
        );
        require(
            rewardData[_rewardsToken].rewardsDistributor == msg.sender,
            "No rewards distributor"
        );
        require(_rewardsDuration > 0, "Reward duration must be non-zero");
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(
            _rewardsToken,
            rewardData[_rewardsToken].rewardsDuration
        );
    }

    function getRewardTokens() external view returns (address[] memory) {
        return rewardTokens;
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        for (uint i; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);
            if (account != address(0)) {
                rewards[account][token] = earned(account, token);
                userRewardPerTokenPaid[account][token] = rewardData[token]
                    .rewardPerTokenStored;
            }
        }
        _;
    }
}

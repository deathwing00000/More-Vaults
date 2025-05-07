// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IMultiRewardsFacet, IMultiRewards} from "../interfaces/facets/IMultiRewardsFacet.sol";

/**
 * @title MultiRewardsFacet
 * @notice Facet for handling staking into Curve's MultiRewards smart contract
 * @dev Implements functionality to stake/withdraw of the lp tokens and claim of rewards
 */
contract MultiRewardsFacet is IMultiRewardsFacet, BaseFacetInitializer {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 constant MULTI_REWARDS_STAKINGS_ID =
        keccak256("MULTI_REWARDS_STAKINGS_ID");

    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.MultiRewardsFacet");
    }

    /**
     * @notice Returns the name of the facet
     * @return The facet name
     */
    function facetName() external pure returns (string memory) {
        return "MultiRewardsFacet";
    }

    function accountingMultiRewardsFacet() external view returns (uint256 sum) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        EnumerableSet.AddressSet storage stakings = ds.stakingAddresses[
            MULTI_REWARDS_STAKINGS_ID
        ];

        for (uint256 i = 0; i < stakings.length(); ) {
            IMultiRewards staking = IMultiRewards(stakings.at(i));
            address[] memory rewardTokens = staking.getRewardTokens();
            for (uint256 j = 0; j < rewardTokens.length; ) {
                uint256 balance = staking.earned(
                    address(this),
                    rewardTokens[j]
                );

                sum += MoreVaultsLib.convertToUnderlying(
                    rewardTokens[j],
                    balance
                );
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    function initialize(bytes calldata data) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.supportedInterfaces[type(IMultiRewardsFacet).interfaceId] = true;
        address facetAddress = abi.decode(data, (address));
        ds.facetsForAccounting.push(facetAddress);
    }

    /**
     * @inheritdoc IMultiRewardsFacet
     */
    function stake(address staking, uint256 amount) external {
        AccessControlLib.validateDiamond(msg.sender);
        IMultiRewards _staking = IMultiRewards(staking);
        address[] memory rewardTokens = _staking.getRewardTokens();
        for (uint256 i; i < rewardTokens.length; ) {
            MoreVaultsLib.validateAssetAvailable(rewardTokens[i]);
            unchecked {
                ++i;
            }
        }
        IERC20 stakingToken = _staking.stakingToken();
        stakingToken.approve(staking, amount);
        _staking.stake(amount);

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.stakingAddresses[MULTI_REWARDS_STAKINGS_ID].add(staking);
        ds.staked[address(stakingToken)] += amount;
    }

    /**
     * @inheritdoc IMultiRewardsFacet
     */
    function withdraw(address staking, uint256 amount) public {
        AccessControlLib.validateDiamond(msg.sender);
        IMultiRewards(staking).withdraw(amount);

        IERC20 stakingToken = IMultiRewards(staking).stakingToken();
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.staked[address(stakingToken)] -= amount;
    }

    /**
     * @inheritdoc IMultiRewardsFacet
     */
    function getReward(address staking) public {
        AccessControlLib.validateDiamond(msg.sender);
        IMultiRewards _staking = IMultiRewards(staking);
        address[] memory rewardTokens = _staking.getRewardTokens();
        for (uint256 i; i < rewardTokens.length; ) {
            MoreVaultsLib.validateAssetAvailable(rewardTokens[i]);
            unchecked {
                ++i;
            }
        }
        _staking.getReward();

        if (_staking.balanceOf(address(this)) == 0) {
            MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
                .moreVaultsStorage();
            ds.stakingAddresses[MULTI_REWARDS_STAKINGS_ID].remove(staking);
        }
    }

    /**
     * @inheritdoc IMultiRewardsFacet
     */
    function exit(address staking) external {
        AccessControlLib.validateDiamond(msg.sender);
        withdraw(staking, IMultiRewards(staking).balanceOf(address(this)));
        getReward(staking);
    }
}

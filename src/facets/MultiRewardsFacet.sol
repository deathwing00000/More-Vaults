// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IMultiRewardsFacet, IMultiRewards} from "../interfaces/facets/IMultiRewardsFacet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title MultiRewardsFacet
 * @notice Facet for handling staking into Curve's MultiRewards smart contract
 * @dev Implements functionality to stake/withdraw of the lp tokens and claim of rewards
 */
contract MultiRewardsFacet is IMultiRewardsFacet, BaseFacetInitializer {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

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

    function facetVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    function accountingMultiRewardsFacet()
        external
        view
        returns (uint256 sum, bool isPositive)
    {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        EnumerableSet.AddressSet storage stakings = ds.stakingAddresses[
            MULTI_REWARDS_STAKINGS_ID
        ];

        for (uint256 i = 0; i < stakings.length(); ) {
            IMultiRewards staking = IMultiRewards(stakings.at(i));
            address[] memory rewardTokens = staking.getRewardTokens();
            for (uint256 j = 0; j < rewardTokens.length; ) {
                if (!ds.isAssetAvailable[rewardTokens[j]]) {
                    ++j;
                    continue;
                }
                uint256 balance = staking.earned(
                    address(this),
                    rewardTokens[j]
                );

                sum += MoreVaultsLib.convertToUnderlying(
                    rewardTokens[j],
                    balance,
                    Math.Rounding.Floor
                );
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
        isPositive = true;
    }

    function initialize(bytes calldata data) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.supportedInterfaces[type(IMultiRewardsFacet).interfaceId] = true;
        bytes32 facetSelector = abi.decode(data, (bytes32));
        ds.facetsForAccounting.push(facetSelector);
        ds.vaultExternalAssets[MoreVaultsLib.TokenType.StakingToken].add(
            MULTI_REWARDS_STAKINGS_ID
        );
    }

    function onFacetRemoval(address facetAddress, bool isReplacing) external {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.supportedInterfaces[type(IMultiRewardsFacet).interfaceId] = false;

        MoreVaultsLib.removeFromFacetsForAccounting(
            ds,
            facetAddress,
            isReplacing
        );

        if (!isReplacing) {
            ds.vaultExternalAssets[MoreVaultsLib.TokenType.StakingToken].remove(
                MULTI_REWARDS_STAKINGS_ID
            );
        }
    }

    /**
     * @inheritdoc IMultiRewardsFacet
     */
    function stake(address staking, uint256 amount) external {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAddressWhitelisted(staking);
        IMultiRewards _staking = IMultiRewards(staking);
        address[] memory rewardTokens = _staking.getRewardTokens();

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        if (!ds.stakingAddresses[MULTI_REWARDS_STAKINGS_ID].contains(staking)) {
            for (uint256 i; i < rewardTokens.length; ) {
                MoreVaultsLib.validateAssetAvailable(rewardTokens[i]);
                unchecked {
                    ++i;
                }
            }
        }
        IERC20 stakingToken = _staking.stakingToken();
        stakingToken.forceApprove(staking, amount);
        _staking.stake(amount);

        ds.stakingAddresses[MULTI_REWARDS_STAKINGS_ID].add(staking);
        ds.stakingTokenToMultiRewards[address(stakingToken)] = staking;
        ds.staked[address(stakingToken)] += amount;
    }

    /**
     * @inheritdoc IMultiRewardsFacet
     */
    function withdraw(address staking, uint256 amount) public {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAddressWhitelisted(staking);
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
        MoreVaultsLib.validateAddressWhitelisted(staking);
        IMultiRewards _staking = IMultiRewards(staking);
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
        MoreVaultsLib.validateAddressWhitelisted(staking);
        withdraw(staking, IMultiRewards(staking).balanceOf(address(this)));
        getReward(staking);
    }
}

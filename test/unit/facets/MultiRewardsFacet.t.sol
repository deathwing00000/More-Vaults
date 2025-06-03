// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {BaseFacetInitializer, IMultiRewardsFacet, MultiRewardsFacet, IMultiRewards, IERC20} from "../../../src/facets/MultiRewardsFacet.sol";
import {AccessControlLib} from "../../../src/libraries/AccessControlLib.sol";
import {MoreVaultsStorageHelper} from "../../helper/MoreVaultsStorageHelper.sol";
import {MoreVaultsLib} from "../../../src/libraries/MoreVaultsLib.sol";
import {IMoreVaultsRegistry} from "../../../src/interfaces/IMoreVaultsRegistry.sol";

contract MultiRewardsFacetTest is Test {
    MultiRewardsFacet public facet;

    address public zeroAddress = address(0);
    address public lpToken = address(1111);
    address public staking = address(2222);
    address public rewardToken = address(3333);
    address public registry = address(4444);

    function setUp() public {
        // Deploy facet
        facet = new MultiRewardsFacet();

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = rewardToken;
        MoreVaultsStorageHelper.setAvailableAssets(
            address(facet),
            rewardTokens
        );
        MoreVaultsStorageHelper.setMoreVaultsRegistry(address(facet), registry);

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                staking
            ),
            abi.encode(true)
        );
    }

    function test_facetName_ShouldReturnCorrectName() public view {
        assertEq(
            facet.facetName(),
            "MultiRewardsFacet",
            "Facet name should be correct"
        );
    }

    function test_initialize_ShouldSetParametersCorrectly() public {
        MultiRewardsFacet(facet).initialize(abi.encode(facet));
        address[] memory facets = MoreVaultsStorageHelper
            .getFacetsForAccounting(address(facet));
        assertEq(
            facets.length,
            1,
            "Facets for accounting length should be equal to 1"
        );
        assertEq(
            facets[0],
            address(facet),
            "Facet stored should be equal to facet address"
        );
        assertEq(
            MoreVaultsStorageHelper.getSupportedInterface(
                address(facet),
                type(IMultiRewardsFacet).interfaceId
            ),
            true,
            "Supported interfaces should be set"
        );
    }

    function test_stake_ShouldAddStakingAddressToMapping() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = rewardToken;

        // Mock calls
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.getRewardTokens.selector),
            abi.encode(rewardTokens)
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.stakingToken.selector),
            abi.encode(lpToken)
        );
        vm.mockCall(
            lpToken,
            abi.encodeWithSelector(IERC20.approve.selector, staking, amount),
            abi.encode(true)
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.stake.selector, amount),
            abi.encode()
        );

        facet.stake(staking, amount);

        address[] memory stakings = MoreVaultsStorageHelper.getStakingsEntered(
            address(facet),
            keccak256("MULTI_REWARDS_STAKINGS_ID")
        );
        assertEq(stakings.length, 1, "Should have one staking");
        assertEq(stakings[0], staking, "Should have correct stakings");
        assertEq(
            MoreVaultsStorageHelper.getStaked(address(facet), lpToken),
            amount
        );

        vm.stopPrank();
    }

    function test_stake_ShouldRevertIfRewardTokensNotSupported() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;

        address[] memory rewardTokens = new address[](1);
        address unsupportedToken = address(4444);
        rewardTokens[0] = unsupportedToken;
        // Mock calls
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.getRewardTokens.selector),
            abi.encode(rewardTokens)
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.stakingToken.selector),
            abi.encode(lpToken)
        );
        vm.mockCall(
            lpToken,
            abi.encodeWithSelector(IERC20.approve.selector, staking, amount),
            abi.encode(true)
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.stake.selector, amount),
            abi.encode()
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                unsupportedToken
            )
        );
        facet.stake(staking, amount);

        vm.stopPrank();
    }

    function test_stake_ShouldRevertIfStakingAddressIsNotWhitelisted() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                staking
            ),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                staking
            )
        );
        facet.stake(staking, amount);

        vm.stopPrank();
    }

    function test_withdraw_ShouldPerformWithdraw() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;

        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.stakingToken.selector),
            abi.encode(lpToken)
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.balanceOf.selector),
            abi.encode(0)
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.withdraw.selector, amount),
            abi.encode()
        );

        MoreVaultsStorageHelper.setStaked(address(facet), lpToken, amount);

        facet.withdraw(staking, amount);

        assertEq(MoreVaultsStorageHelper.getStaked(address(facet), lpToken), 0);

        vm.stopPrank();
    }

    function test_withdraw_ShouldRevertIfStakingAddressIsNotWhitelisted()
        public
    {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                staking
            ),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                staking
            )
        );
        facet.withdraw(staking, amount);

        vm.stopPrank();
    }

    function test_getReward_ShouldRemoveStakingAddressFromMappingIfBalanceIsZero()
        public
    {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = rewardToken;
        // Mock calls
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.getRewardTokens.selector),
            abi.encode(rewardTokens)
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.stakingToken.selector),
            abi.encode(lpToken)
        );
        vm.mockCall(
            lpToken,
            abi.encodeWithSelector(IERC20.approve.selector, staking, amount),
            abi.encode(true)
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.stake.selector, amount),
            abi.encode()
        );

        facet.stake(staking, amount);

        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.getRewardTokens.selector),
            abi.encode(rewardTokens)
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.getReward.selector),
            abi.encode()
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.balanceOf.selector),
            abi.encode(0)
        );

        facet.getReward(staking);
        address[] memory stakings = MoreVaultsStorageHelper.getStakingsEntered(
            address(facet),
            keccak256("MULTI_REWARDS_STAKINGS_ID")
        );
        assertEq(stakings.length, 0, "Should have zero stakings");

        vm.stopPrank();
    }

    function test_getReward_ShouldntRemoveStakingAddressFromMappingIfBalanceIsntZero()
        public
    {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = rewardToken;
        // Mock calls
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.getRewardTokens.selector),
            abi.encode(rewardTokens)
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.stakingToken.selector),
            abi.encode(lpToken)
        );
        vm.mockCall(
            lpToken,
            abi.encodeWithSelector(IERC20.approve.selector, staking, amount),
            abi.encode(true)
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.stake.selector, amount),
            abi.encode()
        );

        facet.stake(staking, amount);

        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.getRewardTokens.selector),
            abi.encode(rewardTokens)
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.getReward.selector),
            abi.encode()
        );
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.balanceOf.selector),
            abi.encode(1)
        );

        facet.getReward(staking);
        address[] memory stakings = MoreVaultsStorageHelper.getStakingsEntered(
            address(facet),
            keccak256("MULTI_REWARDS_STAKINGS_ID")
        );
        assertEq(stakings.length, 1, "Should have one staking");
        assertEq(
            stakings[0],
            staking,
            "Stored staking should be equal to staking address"
        );

        vm.stopPrank();
    }

    function test_getReward_ShouldRevertIfStakingAddressIsNotWhitelisted()
        public
    {
        vm.startPrank(address(facet));

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                staking
            ),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                staking
            )
        );
        facet.getReward(staking);

        vm.stopPrank();
    }

    function test_exit_ShouldRevertIfStakingAddressIsNotWhitelisted() public {
        vm.startPrank(address(facet));

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                staking
            ),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                staking
            )
        );
        facet.exit(staking);

        vm.stopPrank();
    }
}

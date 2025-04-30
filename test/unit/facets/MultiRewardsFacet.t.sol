// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {BaseFacetInitializer, IMultiRewardsFacet, MultiRewardsFacet, IMultiRewards, IERC20} from "../../../src/facets/MultiRewardsFacet.sol";
import {AccessControlLib} from "../../../src/libraries/AccessControlLib.sol";
import {MoreVaultsStorageHelper} from "../../helper/MoreVaultsStorageHelper.sol";
import {MoreVaultsLib} from "../../../src/libraries/MoreVaultsLib.sol";

contract MultiRewardsFacetTest is Test {
    MultiRewardsFacet public facet;

    address public zeroAddress = address(0);
    address public lpToken = address(1111);
    address public staking = address(2222);
    address public rewardToken = address(3333);

    function setUp() public {
        // Deploy facet
        facet = new MultiRewardsFacet();

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = rewardToken;
        MoreVaultsStorageHelper.setAvailableAssets(
            address(facet),
            rewardTokens
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

    function test_stake_ShouldPerformWithdraw() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;

        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.withdraw.selector, amount),
            abi.encode()
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

    function test_getReward_ShouldRevertIfRewardTokensNotSupported() public {
        vm.startPrank(address(facet));

        address[] memory rewardTokens = new address[](1);
        address unsupportedToken = address(4444);
        rewardTokens[0] = unsupportedToken;
        // Mock calls
        vm.mockCall(
            staking,
            abi.encodeWithSelector(IMultiRewards.getRewardTokens.selector),
            abi.encode(rewardTokens)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                unsupportedToken
            )
        );
        facet.getReward(staking);

        vm.stopPrank();
    }

    // function test_submitActions_ShouldExecuteActionsIfTimeLockPeriodIsZero()
    //     public
    // {
    //     vm.startPrank(curator);

    //     MoreVaultsStorageHelper.setTimeLockPeriod(address(facet), 0);

    //     // Mock function calls
    //     vm.mockCall(
    //         address(facet),
    //         abi.encodeWithSignature("mockFunction1()"),
    //         abi.encode()
    //     );
    //     vm.mockCall(
    //         address(facet),
    //         abi.encodeWithSignature("mockFunction2()"),
    //         abi.encode()
    //     );

    //     vm.expectEmit();
    //     emit IMulticallFacet.ActionsSubmitted(
    //         curator,
    //         currentNonce,
    //         block.timestamp,
    //         actionsData
    //     );
    //     vm.expectEmit();
    //     emit IMulticallFacet.ActionsExecuted(curator, currentNonce);
    //     // Submit actions
    //     uint256 nonce = facet.submitActions(actionsData);

    //     // Verify pending actions
    //     (bytes[] memory storedActions, uint256 pendingUntil) = facet
    //         .getPendingActions(nonce);
    //     assertEq(storedActions.length, 0, "Actions length should be deleted");
    //     assertEq(pendingUntil, 0, "Pending until should be deleted");

    //     vm.stopPrank();
    // }

    // function test_submitActions_ShouldRevertWhenUnauthorized() public {
    //     vm.startPrank(unauthorized);

    //     // Attempt to submit actions
    //     vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
    //     facet.submitActions(actionsData);

    //     vm.stopPrank();
    // }

    // function test_submitActions_ShouldRevertWhenEmptyActions() public {
    //     vm.startPrank(curator);

    //     // Attempt to submit empty actions
    //     bytes[] memory emptyActions = new bytes[](0);
    //     vm.expectRevert(IMulticallFacet.EmptyActions.selector);
    //     facet.submitActions(emptyActions);

    //     vm.stopPrank();
    // }

    // function test_executeActions_ShouldExecuteActions() public {
    //     vm.startPrank(curator);

    //     // Submit actions
    //     uint256 nonce = facet.submitActions(actionsData);

    //     // Mock function calls
    //     vm.mockCall(
    //         address(facet),
    //         abi.encodeWithSignature("mockFunction1()"),
    //         abi.encode()
    //     );
    //     vm.mockCall(
    //         address(facet),
    //         abi.encodeWithSignature("mockFunction2()"),
    //         abi.encode()
    //     );

    //     // Fast forward time
    //     vm.warp(block.timestamp + timeLockPeriod + 1);

    //     // Execute actions
    //     facet.executeActions(nonce);

    //     // Verify actions were deleted
    //     (bytes[] memory storedActions, uint256 pendingUntil) = facet
    //         .getPendingActions(nonce);
    //     assertEq(storedActions.length, 0, "Actions should be deleted");
    //     assertEq(pendingUntil, 0, "Pending until should be zero");

    //     vm.stopPrank();
    // }

    // function test_executeActions_ShouldRevertWhenActionsStillPending() public {
    //     vm.startPrank(curator);

    //     // Submit actions
    //     uint256 nonce = facet.submitActions(actionsData);

    //     // Attempt to execute actions before time lock period
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IMulticallFacet.ActionsStillPending.selector,
    //             nonce
    //         )
    //     );
    //     facet.executeActions(nonce);

    //     vm.stopPrank();
    // }

    // function test_executeActions_ShouldRevertWhenNoSuchActions() public {
    //     vm.startPrank(curator);

    //     // Attempt to execute non-existent actions
    //     vm.expectRevert(
    //         abi.encodeWithSelector(IMulticallFacet.NoSuchActions.selector, 999)
    //     );
    //     facet.executeActions(999);

    //     vm.stopPrank();
    // }

    // function test_executeActions_ShouldRevertWhenMulticallFailed() public {
    //     vm.startPrank(curator);

    //     // Submit actions
    //     uint256 nonce = facet.submitActions(actionsData);

    //     // Fast forward time
    //     vm.warp(block.timestamp + timeLockPeriod + 1);

    //     // Attempt to execute actions
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             bytes4(keccak256("MulticallFailed(uint256,bytes)")),
    //             0,
    //             ""
    //         )
    //     );
    //     facet.executeActions(nonce);
    //     vm.stopPrank();
    // }

    // function test_vetoActions_ShouldVetoActions() public {
    //     vm.startPrank(curator);

    //     // Submit actions
    //     uint256 nonce = facet.submitActions(actionsData);

    //     vm.stopPrank();
    //     vm.startPrank(guardian);

    //     // Veto actions
    //     facet.vetoActions(nonce);

    //     // Verify actions were deleted
    //     (bytes[] memory storedActions, uint256 pendingUntil) = facet
    //         .getPendingActions(nonce);
    //     assertEq(storedActions.length, 0, "Actions should be deleted");
    //     assertEq(pendingUntil, 0, "Pending until should be zero");

    //     vm.stopPrank();
    // }

    // function test_vetoActions_ShouldRevertWhenUnauthorized() public {
    //     vm.startPrank(curator);

    //     // Submit actions
    //     uint256 nonce = facet.submitActions(actionsData);

    //     vm.stopPrank();
    //     vm.startPrank(unauthorized);

    //     // Attempt to veto actions
    //     vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
    //     facet.vetoActions(nonce);

    //     vm.stopPrank();
    // }

    // function test_vetoActions_ShouldRevertWhenNoSuchActions() public {
    //     vm.startPrank(guardian);

    //     // Attempt to veto non-existent actions
    //     vm.expectRevert(
    //         abi.encodeWithSelector(IMulticallFacet.NoSuchActions.selector, 999)
    //     );
    //     facet.vetoActions(999);

    //     vm.stopPrank();
    // }

    // function test_getPendingActions_ShouldReturnCorrectData() public {
    //     vm.startPrank(curator);

    //     // Submit actions
    //     uint256 nonce = facet.submitActions(actionsData);

    //     // Get pending actions
    //     (bytes[] memory storedActions, uint256 pendingUntil) = facet
    //         .getPendingActions(nonce);

    //     // Verify data
    //     assertEq(
    //         storedActions.length,
    //         actionsData.length,
    //         "Actions length should match"
    //     );
    //     assertEq(
    //         pendingUntil,
    //         block.timestamp + timeLockPeriod,
    //         "Pending until should be correct"
    //     );

    //     vm.stopPrank();
    // }

    // function test_getCurrentNonce_ShouldReturnCorrectNonce() public view {
    //     assertEq(
    //         facet.getCurrentNonce(),
    //         currentNonce,
    //         "Current nonce should match"
    //     );
    // }
}

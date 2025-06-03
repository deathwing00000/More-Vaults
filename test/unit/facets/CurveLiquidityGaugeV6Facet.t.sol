// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {BaseFacetInitializer, ICurveLiquidityGaugeV6Facet, CurveLiquidityGaugeV6Facet, ILiquidityGaugeV6, IMinter, IERC20} from "../../../src/facets/CurveLiquidityGaugeV6Facet.sol";
import {AccessControlLib} from "../../../src/libraries/AccessControlLib.sol";
import {MoreVaultsStorageHelper} from "../../helper/MoreVaultsStorageHelper.sol";
import {MoreVaultsLib} from "../../../src/libraries/MoreVaultsLib.sol";
import {IMoreVaultsRegistry} from "../../../src/interfaces/IMoreVaultsRegistry.sol";

contract CurveLiquidityGaugeV6FacetTest is Test {
    CurveLiquidityGaugeV6Facet public facet;

    address public zeroAddress = address(0);
    address public lpToken = address(1111);
    address public gauge = address(2222);
    address public crvMinter = address(2223);
    address public rewardToken = address(3333);
    address public registry = address(4444);

    function setUp() public {
        // Deploy facet
        facet = new CurveLiquidityGaugeV6Facet();

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
                gauge
            ),
            abi.encode(true)
        );
    }

    function test_facetName_ShouldReturnCorrectName() public view {
        assertEq(
            facet.facetName(),
            "CurveLiquidityGaugeV6Facet",
            "Facet name should be correct"
        );
    }

    function test_initialize_ShouldSetParametersCorrectly() public {
        CurveLiquidityGaugeV6Facet(facet).initialize(abi.encode(facet));
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
                type(ICurveLiquidityGaugeV6Facet).interfaceId
            ),
            true,
            "Supported interfaces should be set"
        );
    }

    function test_depositCurveGaugeV6_ShouldAddStakingAddressToMapping()
        public
    {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;

        // Mock calls
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.reward_count.selector),
            abi.encode(1)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.reward_tokens.selector, 0),
            abi.encode(rewardToken)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.lp_token.selector),
            abi.encode(lpToken)
        );
        vm.mockCall(
            lpToken,
            abi.encodeWithSelector(IERC20.approve.selector, gauge, amount),
            abi.encode(true)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(
                ILiquidityGaugeV6.deposit.selector,
                amount,
                address(facet),
                false
            ),
            abi.encode()
        );

        facet.depositCurveGaugeV6(gauge, amount);

        address[] memory stakings = MoreVaultsStorageHelper.getStakingsEntered(
            address(facet),
            keccak256("CURVE_LIQUIDITY_GAUGES_V6_ID")
        );
        assertEq(stakings.length, 1, "Should have one staking");
        assertEq(stakings[0], gauge, "Should have correct stakings");
        assertEq(
            MoreVaultsStorageHelper.getStaked(address(facet), lpToken),
            amount
        );

        vm.stopPrank();
    }

    function test_depositCurveGaugeV6_ShouldRevertIfGaugeIsNotWhitelisted()
        public
    {
        vm.startPrank(address(facet));

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                gauge
            ),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                gauge
            )
        );
        facet.depositCurveGaugeV6(gauge, 1e18);

        vm.stopPrank();
    }

    function test_withdrawCurveGaugeV6_ShouldPerformWithdraw() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;

        vm.mockCall(
            gauge,
            abi.encodeWithSelector(
                ILiquidityGaugeV6.withdraw.selector,
                amount,
                false
            ),
            abi.encode()
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.lp_token.selector),
            abi.encode(lpToken)
        );

        MoreVaultsStorageHelper.setStaked(address(facet), lpToken, amount);
        assertEq(
            MoreVaultsStorageHelper.getStaked(address(facet), lpToken),
            amount
        );

        facet.withdrawCurveGaugeV6(gauge, amount);

        assertEq(MoreVaultsStorageHelper.getStaked(address(facet), lpToken), 0);

        vm.stopPrank();
    }

    function test_withdrawCurveGaugeV6_ShouldRevertIfGaugeIsNotWhitelisted()
        public
    {
        vm.startPrank(address(facet));

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                gauge
            ),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                gauge
            )
        );
        facet.withdrawCurveGaugeV6(gauge, 1e18);

        vm.stopPrank();
    }

    function test_claimRewardsCurveGaugeV6_ShouldRemoveStakingAddressFromMappingIfBalanceIsZero()
        public
    {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        // Mock calls
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.reward_count.selector),
            abi.encode(1)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.reward_tokens.selector, 0),
            abi.encode(rewardToken)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.lp_token.selector),
            abi.encode(lpToken)
        );
        vm.mockCall(
            lpToken,
            abi.encodeWithSelector(IERC20.approve.selector, gauge, amount),
            abi.encode(true)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(
                ILiquidityGaugeV6.deposit.selector,
                amount,
                address(facet),
                false
            ),
            abi.encode()
        );

        facet.depositCurveGaugeV6(gauge, amount);

        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.reward_count.selector),
            abi.encode(1)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.reward_tokens.selector, 0),
            abi.encode(rewardToken)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(
                ILiquidityGaugeV6.claim_rewards.selector,
                address(facet),
                address(facet)
            ),
            abi.encode(rewardToken)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(IERC20.balanceOf.selector),
            abi.encode(0)
        );

        facet.claimRewardsCurveGaugeV6(gauge);
        address[] memory stakings = MoreVaultsStorageHelper.getStakingsEntered(
            address(facet),
            keccak256("CURVE_LIQUIDITY_GAUGES_V6_ID")
        );
        assertEq(stakings.length, 0, "Should have zero stakings");

        vm.stopPrank();
    }

    function test_claimRewardsCurveGaugeV6_ShouldntRemoveStakingAddressFromMappingIfBalanceIsntZero()
        public
    {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        // Mock calls
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.reward_count.selector),
            abi.encode(1)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.reward_tokens.selector, 0),
            abi.encode(rewardToken)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.lp_token.selector),
            abi.encode(lpToken)
        );
        vm.mockCall(
            lpToken,
            abi.encodeWithSelector(IERC20.approve.selector, gauge, amount),
            abi.encode(true)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(
                ILiquidityGaugeV6.deposit.selector,
                amount,
                address(facet),
                false
            ),
            abi.encode()
        );

        facet.depositCurveGaugeV6(gauge, amount);

        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.reward_count.selector),
            abi.encode(1)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(ILiquidityGaugeV6.reward_tokens.selector, 0),
            abi.encode(rewardToken)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(
                ILiquidityGaugeV6.claim_rewards.selector,
                address(facet),
                address(facet)
            ),
            abi.encode(rewardToken)
        );
        vm.mockCall(
            gauge,
            abi.encodeWithSelector(IERC20.balanceOf.selector),
            abi.encode(1)
        );

        facet.claimRewardsCurveGaugeV6(gauge);
        address[] memory gauges = MoreVaultsStorageHelper.getStakingsEntered(
            address(facet),
            keccak256("CURVE_LIQUIDITY_GAUGES_V6_ID")
        );
        assertEq(gauges.length, 1, "Should have one staking");
        assertEq(
            gauges[0],
            gauge,
            "Stored staking should be equal to staking address"
        );

        vm.stopPrank();
    }

    function test_claimRewardsCurveGaugeV6_ShouldRevertIfGaugeIsNotWhitelisted()
        public
    {
        vm.startPrank(address(facet));

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                gauge
            ),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                gauge
            )
        );
        facet.claimRewardsCurveGaugeV6(gauge);

        vm.stopPrank();
    }

    function test_mintCRV_ShouldPerformMint() public {
        vm.startPrank(address(facet));

        // Mock calls
        vm.mockCall(
            crvMinter,
            abi.encodeWithSelector(IMinter.mint.selector, gauge),
            abi.encode()
        );
        vm.mockCall(
            crvMinter,
            abi.encodeWithSelector(IMinter.token.selector),
            abi.encode(rewardToken)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                crvMinter
            ),
            abi.encode(true)
        );
        facet.mintCRV(crvMinter, gauge);

        vm.stopPrank();
    }

    function test_mintCRV_ShouldRevertIfMintedTokenNotSupported() public {
        vm.startPrank(address(facet));

        address unsupportedToken = address(4444);

        // Mock calls
        vm.mockCall(
            crvMinter,
            abi.encodeWithSelector(IMinter.mint.selector, gauge),
            abi.encode()
        );
        vm.mockCall(
            crvMinter,
            abi.encodeWithSelector(IMinter.token.selector),
            abi.encode(unsupportedToken)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                unsupportedToken
            )
        );
        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                crvMinter
            ),
            abi.encode(true)
        );
        facet.mintCRV(crvMinter, gauge);

        vm.stopPrank();
    }

    function test_mintCRV_ShouldRevertIfMinterContractIsNotWhitelisted()
        public
    {
        vm.startPrank(address(facet));

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                crvMinter
            ),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                crvMinter
            )
        );
        facet.mintCRV(crvMinter, gauge);

        vm.stopPrank();
    }
}

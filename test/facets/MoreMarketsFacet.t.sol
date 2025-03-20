// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IMoreMarketsFacet, MoreMarketsFacet} from "../../src/facets/MoreMarketsFacet.sol";
import {MoreVaultsStorageHelper} from "../libraries/MoreVaultsStorageHelper.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {ICreditDelegationToken} from "@aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IATokenExtended} from "../../src/interfaces/Aave/v3/IATokenExtended.sol";
import {IAaveV3RewardsController} from "../../src/interfaces/Aave/v3/IAaveV3RewardsController.sol";
import {IPoolAddressesProviderRegistry} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProviderRegistry.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {DataTypes} from "@aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {IMoreVaultsRegistry} from "../../src/interfaces/IMoreVaultsRegistry.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {BaseFacetInitializer} from "../../src/facets/BaseFacetInitializer.sol";

contract MoreMarketsFacetTest is Test {
    // Test addresses
    address public facet = address(100);
    address public token1 = address(2);
    address public token2 = address(3);
    address public wrappedNative = address(4);
    address public oracle = address(5);
    address public registry = address(6);
    address public pool = address(7);
    address public mToken1 = address(8);
    address public mToken2 = address(9);
    address public debtToken1 = address(10);
    address public debtToken2 = address(11);
    address public curator = address(12);
    address public user = address(13);
    address public rewardsController = address(14);
    address public poolAddressesProvider = address(15);

    // Price constants (in USD with 8 decimals)
    uint256 constant ETH_PRICE = 3000e8; // 3000 USD
    uint256 constant SOL_PRICE = 100e8; // 100 USD
    uint256 constant USD_PRICE = 1e8; // 1 USD

    function setUp() public {
        // Deploy facet
        MoreMarketsFacet facetContract = new MoreMarketsFacet();
        facet = address(facetContract);

        // Set initial values in storage
        address[] memory availableAssets = new address[](2);
        availableAssets[0] = token1;
        availableAssets[1] = token2;
        MoreVaultsStorageHelper.setAvailableAssets(facet, availableAssets);
        MoreVaultsStorageHelper.setWrappedNative(facet, wrappedNative);
        MoreVaultsStorageHelper.setMoreVaultsRegistry(facet, registry);
        MoreVaultsStorageHelper.setCurator(facet, curator);
        MoreVaultsStorageHelper.setMorePoolAddressesProviderRegistry(
            facet,
            registry
        );

        // Mock pool addresses provider registry
        address[] memory providers = new address[](1);
        providers[0] = poolAddressesProvider;
        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IPoolAddressesProviderRegistry
                    .getAddressesProvidersList
                    .selector
            ),
            abi.encode(providers)
        );

        // Mock pool addresses provider to return supported pool
        vm.mockCall(
            poolAddressesProvider,
            abi.encodeWithSelector(IPoolAddressesProvider.getPool.selector),
            abi.encode(pool)
        );

        // Mock pool reserve data
        DataTypes.ReserveData memory reserveData;
        reserveData.aTokenAddress = mToken1;
        reserveData.stableDebtTokenAddress = debtToken1;
        reserveData.variableDebtTokenAddress = debtToken2;
        vm.mockCall(
            pool,
            abi.encodeWithSelector(IPool.getReserveData.selector, token1),
            abi.encode(reserveData)
        );

        // Mock token decimals
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(18)
        );
        vm.mockCall(
            token2,
            abi.encodeWithSelector(IERC20Metadata.decimals.selector),
            abi.encode(8)
        );

        // Mock oracle and prices
        vm.mockCall(
            registry,
            abi.encodeWithSelector(IMoreVaultsRegistry.oracle.selector),
            abi.encode(oracle)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.getDenominationAsset.selector
            ),
            abi.encode(token1)
        );
    }

    function test_initialize_ShouldSetFacetAddress() public {
        MoreMarketsFacet(facet).initialize(abi.encode(facet));
        MoreVaultsStorageHelper.getStorageValue(facet, 0); // Verify storage was updated
    }

    function test_initialize_ShouldRevertWhenAlreadyInitialized() public {
        // First initialization
        MoreMarketsFacet(facet).initialize(abi.encode(facet));

        // Try to initialize again
        vm.expectRevert(BaseFacetInitializer.AlreadyInitialized.selector);
        MoreMarketsFacet(facet).initialize(abi.encode(facet));
    }

    function test_supply_ShouldAddMTokenToHeldTokens() public {
        uint256 amount = 1e18;

        // Mock approvals and supply
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, pool, amount),
            abi.encode(true)
        );
        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.supply.selector,
                token1,
                amount,
                address(this),
                0
            ),
            abi.encode()
        );

        vm.prank(facet);
        MoreMarketsFacet(facet).supply(pool, token1, amount, address(this), 0);

        // Verify mToken was added to held tokens
        address[] memory mTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MTOKENS_ID")
        );
        assertEq(mTokens.length, 1, "Should have one mToken");
        assertEq(mTokens[0], mToken1, "Should have correct mToken");
    }

    function test_withdraw_ShouldRemoveMTokenFromHeldTokens() public {
        uint256 amount = 1e18;

        // First add mToken to held tokens
        address[] memory mTokens = new address[](1);
        mTokens[0] = mToken1;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("MTOKENS_ID"),
            mTokens
        );

        // Mock balance check to return zero balance
        vm.mockCall(
            mToken1,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(0)
        );

        // Mock approvals and withdraw
        vm.mockCall(
            mToken1,
            abi.encodeWithSelector(IERC20.approve.selector, pool, amount),
            abi.encode(true)
        );
        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.withdraw.selector,
                token1,
                amount,
                address(this)
            ),
            abi.encode(amount)
        );

        // Set up as curator
        vm.prank(facet);

        MoreMarketsFacet(facet).withdraw(pool, token1, amount, address(this));

        // Verify mToken was removed from held tokens
        mTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MTOKENS_ID")
        );
        assertEq(mTokens.length, 0, "Should have no mTokens");
    }

    function test_withdraw_ShouldNotRemoveMTokenWhenBalanceIsNonZero() public {
        uint256 amount = 1e18;

        // First add mToken to held tokens
        address[] memory mTokens = new address[](1);
        mTokens[0] = mToken1;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("MTOKENS_ID"),
            mTokens
        );

        // Mock balance check to return zero balance
        vm.mockCall(
            mToken1,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(10e3 + 1)
        );

        // Mock approvals and withdraw
        vm.mockCall(
            mToken1,
            abi.encodeWithSelector(IERC20.approve.selector, pool, amount),
            abi.encode(true)
        );
        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.withdraw.selector,
                token1,
                amount,
                address(this)
            ),
            abi.encode(amount)
        );

        // Set up as curator
        vm.prank(facet);

        MoreMarketsFacet(facet).withdraw(pool, token1, amount, address(this));

        // Verify mToken was not removed from held tokens
        mTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MTOKENS_ID")
        );
        assertEq(mTokens.length, 1, "Should still have one mToken");
        assertEq(mTokens[0], mToken1, "Should still have correct mToken");
    }

    function test_borrow_ShouldAddDebtTokenToHeldTokens() public {
        uint256 amount = 1e18;

        // Mock borrow
        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.borrow.selector,
                token1,
                amount,
                1,
                0,
                address(this)
            ),
            abi.encode()
        );

        // Set up as curator
        vm.prank(facet);

        MoreMarketsFacet(facet).borrow(
            pool,
            token1,
            amount,
            1,
            0,
            address(this)
        );

        // Verify debt token was added to held tokens
        address[] memory debtTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID")
        );
        assertEq(debtTokens.length, 1, "Should have one debt token");
        assertEq(debtTokens[0], debtToken1, "Should have correct debt token");
    }

    function test_repay_ShouldRemoveDebtTokenFromHeldTokens() public {
        uint256 amount = 1e18;

        // First add debt token to held tokens
        address[] memory debtTokens = new address[](1);
        debtTokens[0] = debtToken1;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID"),
            debtTokens
        );

        // Mock balance check to return zero balance
        vm.mockCall(
            debtToken1,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(0)
        );

        // Mock approvals and repay
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, pool, amount),
            abi.encode(true)
        );
        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.repay.selector,
                token1,
                amount,
                1,
                address(this)
            ),
            abi.encode(amount)
        );

        // Set up as curator
        vm.prank(facet);

        MoreMarketsFacet(facet).repay(pool, token1, amount, 1, address(this));

        // Verify debt token was removed from held tokens
        debtTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID")
        );
        assertEq(debtTokens.length, 0, "Should have no debt tokens");
    }

    function test_repay_ShouldNotRemoveDebtTokenWhenBalanceIsNonZero() public {
        uint256 amount = 1e18;

        // First add debt token to held tokens
        address[] memory debtTokens = new address[](1);
        debtTokens[0] = debtToken1;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID"),
            debtTokens
        );

        // Mock balance check to return zero balance
        vm.mockCall(
            debtToken1,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(10e3 + 1)
        );

        // Mock approvals and repay
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, pool, amount),
            abi.encode(true)
        );
        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.repay.selector,
                token1,
                amount,
                1,
                address(this)
            ),
            abi.encode(amount)
        );

        // Set up as curator
        vm.prank(facet);

        MoreMarketsFacet(facet).repay(pool, token1, amount, 1, address(this));

        // Verify debt token was not removed from held tokens
        debtTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID")
        );
        assertEq(debtTokens.length, 1, "Should still have one debt token");
        assertEq(
            debtTokens[0],
            debtToken1,
            "Should still have correct debt token"
        );
    }

    function test_claimAllRewards_ShouldCallClaimAllRewards() public {
        address[] memory assets = new address[](2);
        assets[0] = token1;
        assets[1] = token2;

        // Mock claimAllRewards
        address[] memory rewardsList = new address[](1);
        rewardsList[0] = token1;
        uint256[] memory claimedAmounts = new uint256[](1);
        claimedAmounts[0] = 1e18;

        vm.mockCall(
            rewardsController,
            abi.encodeWithSelector(
                IAaveV3RewardsController.claimAllRewards.selector,
                assets,
                address(this)
            ),
            abi.encode(rewardsList, claimedAmounts)
        );

        // Set up as curator
        vm.prank(facet);

        (
            address[] memory returnedRewardsList,
            uint256[] memory returnedClaimedAmounts
        ) = MoreMarketsFacet(facet).claimAllRewards(
                rewardsController,
                assets,
                address(this)
            );

        assertEq(
            returnedRewardsList.length,
            1,
            "Should return correct rewards list length"
        );
        assertEq(
            returnedClaimedAmounts.length,
            1,
            "Should return correct claimed amounts length"
        );
        assertEq(
            returnedRewardsList[0],
            token1,
            "Should return correct reward token"
        );
        assertEq(
            returnedClaimedAmounts[0],
            1e18,
            "Should return correct claimed amount"
        );
    }

    function test_validatePool_ShouldRevertForUnsupportedPool() public {
        address unsupportedPool = address(999);

        // Mock pool addresses provider registry to return list with one provider
        address[] memory providers = new address[](1);
        providers[0] = poolAddressesProvider;
        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IPoolAddressesProviderRegistry
                    .getAddressesProvidersList
                    .selector
            ),
            abi.encode(providers)
        );

        // Mock pool addresses provider to return unsupported pool
        vm.mockCall(
            poolAddressesProvider,
            abi.encodeWithSelector(IPoolAddressesProvider.getPool.selector),
            abi.encode(pool)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IMoreMarketsFacet.UnsupportedPool.selector,
                unsupportedPool
            )
        );

        vm.prank(facet);
        MoreMarketsFacet(facet).supply(
            unsupportedPool,
            token1,
            1e18,
            address(this),
            0
        );
    }
}

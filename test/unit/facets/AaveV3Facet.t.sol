// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IAaveV3Facet, AaveV3Facet} from "../../../src/facets/AaveV3Facet.sol";
import {MoreVaultsStorageHelper} from "../../helper/MoreVaultsStorageHelper.sol";
import {IPool} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {ICreditDelegationToken} from "@aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IATokenExtended} from "../../../src/interfaces/Aave/v3/IATokenExtended.sol";
import {IAaveV3RewardsController} from "../../../src/interfaces/Aave/v3/IAaveV3RewardsController.sol";
import {IPoolAddressesProviderRegistry} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProviderRegistry.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {DataTypes} from "@aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";
import {IMoreVaultsRegistry} from "../../../src/interfaces/IMoreVaultsRegistry.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {BaseFacetInitializer} from "../../../src/facets/BaseFacetInitializer.sol";
import {AccessControlLib} from "../../../src/libraries/AccessControlLib.sol";
import {MoreVaultsLib} from "../../../src/libraries/MoreVaultsLib.sol";

contract AaveV3FacetTest is Test {
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
        AaveV3Facet facetContract = new AaveV3Facet();
        facet = address(facetContract);

        // Set initial values in storage
        address[] memory availableAssets = new address[](2);
        availableAssets[0] = token1;
        availableAssets[1] = token2;
        MoreVaultsStorageHelper.setAvailableAssets(facet, availableAssets);
        MoreVaultsStorageHelper.setWrappedNative(facet, wrappedNative);
        MoreVaultsStorageHelper.setMoreVaultsRegistry(facet, registry);
        MoreVaultsStorageHelper.setCurator(facet, curator);

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

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                pool
            ),
            abi.encode(true)
        );
    }

    function test_facetName_ShouldReturnCorrectName() public view {
        assertEq(
            AaveV3Facet(facet).facetName(),
            "AaveV3Facet",
            "Should return correct facet name"
        );
    }

    function test_initialize_ShouldRevertWhenAlreadyInitialized() public {
        // First initialization
        bytes32 facetSelector = keccak256(
            abi.encodePacked("accountingAaveV3Facet()")
        );
        assembly {
            facetSelector := shl(224, facetSelector)
        }
        AaveV3Facet(facet).initialize(abi.encode(facetSelector));

        // Try to initialize again
        vm.expectRevert(BaseFacetInitializer.AlreadyInitialized.selector);
        AaveV3Facet(facet).initialize(abi.encode(facetSelector));
    }

    function test_initialize_ShouldInitializeFacet() public {
        // First initialization
        AaveV3Facet(facet).initialize(abi.encode(facet));

        assertEq(
            MoreVaultsStorageHelper.getSupportedInterface(
                facet,
                type(IAaveV3Facet).interfaceId
            ),
            true
        );
    }

    function test_allNonViewFunctions_ShouldRevertWhenCalledByNonDiamond()
        public
    {
        vm.startPrank(user);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AaveV3Facet(facet).supply(pool, token1, 1e18, 0);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AaveV3Facet(facet).borrow(pool, token1, 1e18, 1, 0, address(this));
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AaveV3Facet(facet).repay(pool, token1, 1e18, 1);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AaveV3Facet(facet).repayWithATokens(pool, token1, 1e18, 1);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AaveV3Facet(facet).swapBorrowRateMode(pool, token1, 1);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AaveV3Facet(facet).rebalanceStableBorrowRate(
            pool,
            token1,
            address(this)
        );
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AaveV3Facet(facet).setUserUseReserveAsCollateral(pool, token1, true);

        bytes memory params = "";
        address[] memory assets = new address[](1);
        assets[0] = token1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e18;
        uint256[] memory interestRateModes = new uint256[](1);
        interestRateModes[0] = 1;

        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AaveV3Facet(facet).flashLoan(
            pool,
            address(this),
            assets,
            amounts,
            interestRateModes,
            address(this),
            params,
            0
        );
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AaveV3Facet(facet).flashLoanSimple(
            pool,
            address(this),
            token1,
            1e18,
            params,
            0
        );
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AaveV3Facet(facet).setUserEMode(pool, 1);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AaveV3Facet(facet).claimAllRewards(rewardsController, new address[](1));

        vm.stopPrank();
    }

    function test_allNonViewFunctions_ShouldRevertWhenCalledToNonWhitelistedPool()
        public
    {
        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                pool
            ),
            abi.encode(false)
        );
        vm.startPrank(facet);
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                pool
            )
        );
        AaveV3Facet(facet).supply(pool, token1, 1e18, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                pool
            )
        );
        AaveV3Facet(facet).borrow(pool, token1, 1e18, 1, 0, address(this));
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                pool
            )
        );
        AaveV3Facet(facet).repay(pool, token1, 1e18, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                pool
            )
        );
        AaveV3Facet(facet).repayWithATokens(pool, token1, 1e18, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                pool
            )
        );
        AaveV3Facet(facet).swapBorrowRateMode(pool, token1, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                pool
            )
        );
        AaveV3Facet(facet).rebalanceStableBorrowRate(
            pool,
            token1,
            address(this)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                pool
            )
        );
        AaveV3Facet(facet).setUserUseReserveAsCollateral(pool, token1, true);

        bytes memory params = "";
        address[] memory assets = new address[](1);
        assets[0] = token1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e18;
        uint256[] memory interestRateModes = new uint256[](1);
        interestRateModes[0] = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                pool
            )
        );
        AaveV3Facet(facet).flashLoan(
            pool,
            address(this),
            assets,
            amounts,
            interestRateModes,
            address(this),
            params,
            0
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                pool
            )
        );
        AaveV3Facet(facet).flashLoanSimple(
            pool,
            address(this),
            token1,
            1e18,
            params,
            0
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                pool
            )
        );
        AaveV3Facet(facet).setUserEMode(pool, 1);

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                rewardsController
            ),
            abi.encode(false)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                rewardsController
            )
        );
        AaveV3Facet(facet).claimAllRewards(rewardsController, new address[](1));

        vm.stopPrank();
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
                address(facet),
                0
            ),
            abi.encode()
        );

        vm.prank(facet);
        AaveV3Facet(facet).supply(pool, token1, amount, 0);

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
                address(facet)
            ),
            abi.encode(amount)
        );

        // Set up as curator
        vm.prank(facet);

        AaveV3Facet(facet).withdraw(pool, token1, amount);

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
                address(facet)
            ),
            abi.encode(amount)
        );

        // Set up as curator
        vm.prank(facet);

        AaveV3Facet(facet).withdraw(pool, token1, amount);

        // Verify mToken was not removed from held tokens
        mTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MTOKENS_ID")
        );
        assertEq(mTokens.length, 1, "Should still have one mToken");
        assertEq(mTokens[0], mToken1, "Should still have correct mToken");
    }

    function test_borrow_ShouldAddStableDebtTokenToHeldTokens() public {
        uint256 amount = 1e18;
        uint256 interestRateMode = 1; // Stable rate

        // Mock borrow
        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.borrow.selector,
                token1,
                amount,
                interestRateMode,
                0,
                address(facet)
            ),
            abi.encode()
        );

        vm.prank(facet);
        AaveV3Facet(facet).borrow(
            pool,
            token1,
            amount,
            interestRateMode,
            0,
            address(facet)
        );

        // Verify debt token was added to held tokens
        address[] memory debtTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID")
        );
        assertEq(debtTokens.length, 1, "Should have one debt token");
        assertEq(debtTokens[0], debtToken1, "Should have correct debt token");
    }

    function test_borrow_ShouldAddVariableDebtTokenToHeldTokens() public {
        uint256 amount = 1e18;
        uint256 interestRateMode = 2; // variable rate

        // Mock borrow
        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.borrow.selector,
                token1,
                amount,
                interestRateMode,
                0,
                address(facet)
            ),
            abi.encode()
        );

        vm.prank(facet);
        AaveV3Facet(facet).borrow(
            pool,
            token1,
            amount,
            interestRateMode,
            0,
            address(facet)
        );

        // Verify debt token was added to held tokens
        address[] memory debtTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID")
        );
        assertEq(debtTokens.length, 1, "Should have one debt token");
        assertEq(debtTokens[0], debtToken2, "Should have correct debt token");
    }

    function test_repay_ShouldRemoveStableDebtTokenFromHeldTokens() public {
        uint256 amount = 1e18;
        uint256 interestRateMode = 1; // Stable rate

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
                interestRateMode,
                address(facet)
            ),
            abi.encode(amount)
        );

        vm.prank(facet);
        AaveV3Facet(facet).repay(pool, token1, amount, interestRateMode);

        // Verify debt token was removed from held tokens
        debtTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID")
        );
        assertEq(debtTokens.length, 0, "Should have no debt tokens");
    }

    function test_repay_ShouldRemoveVariableDebtTokenFromHeldTokens() public {
        uint256 amount = 1e18;
        uint256 interestRateMode = 2; // variable rate

        // First add debt token to held tokens
        address[] memory debtTokens = new address[](1);
        debtTokens[0] = debtToken2;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID"),
            debtTokens
        );

        // Mock balance check to return zero balance
        vm.mockCall(
            debtToken2,
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
                interestRateMode,
                address(facet)
            ),
            abi.encode(amount)
        );

        vm.prank(facet);
        AaveV3Facet(facet).repay(pool, token1, amount, interestRateMode);

        // Verify debt token was removed from held tokens
        debtTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID")
        );
        assertEq(debtTokens.length, 0, "Should have no debt tokens");
    }

    function test_repayWithATokens_ShouldRemoveStableDebtTokenFromHeldTokens()
        public
    {
        uint256 amount = 1e18;
        uint256 interestRateMode = 1; // Stable rate

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
            mToken1,
            abi.encodeWithSelector(IERC20.approve.selector, pool, amount),
            abi.encode(true)
        );
        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.repayWithATokens.selector,
                token1,
                amount,
                interestRateMode
            ),
            abi.encode(amount)
        );

        vm.mockCall(
            mToken1,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(0)
        );

        vm.prank(facet);
        AaveV3Facet(facet).repayWithATokens(
            pool,
            token1,
            amount,
            interestRateMode
        );

        // Verify debt token was removed from held tokens
        debtTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID")
        );
        assertEq(debtTokens.length, 0, "Should have no debt tokens");
    }

    function test_repayWithATokens_ShouldRemoveVariableDebtTokenFromHeldTokens()
        public
    {
        uint256 amount = 1e18;
        uint256 interestRateMode = 2; // variable rate

        // First add debt token to held tokens
        address[] memory debtTokens = new address[](1);
        debtTokens[0] = debtToken2;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID"),
            debtTokens
        );

        // Mock balance check to return zero balance
        vm.mockCall(
            debtToken2,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(0)
        );

        // Mock approvals and repay
        vm.mockCall(
            mToken1,
            abi.encodeWithSelector(IERC20.approve.selector, pool, amount),
            abi.encode(true)
        );
        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.repayWithATokens.selector,
                token1,
                amount,
                interestRateMode
            ),
            abi.encode(amount)
        );

        vm.mockCall(
            mToken1,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(0)
        );

        vm.prank(facet);
        AaveV3Facet(facet).repayWithATokens(
            pool,
            token1,
            amount,
            interestRateMode
        );

        // Verify debt token was removed from held tokens
        debtTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID")
        );
        assertEq(debtTokens.length, 0, "Should have no debt tokens");
    }

    function test_swapBorrowRateMode_ShouldUpdateSwapFromVariableToStable()
        public
    {
        uint256 interestRateMode = 1; // Stable rate

        // First add variable debt token to held tokens
        address[] memory debtTokens = new address[](1);
        debtTokens[0] = debtToken2;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID"),
            debtTokens
        );

        // Mock swap rate mode
        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.swapBorrowRateMode.selector,
                token1,
                interestRateMode
            ),
            abi.encode()
        );

        vm.prank(facet);
        AaveV3Facet(facet).swapBorrowRateMode(pool, token1, interestRateMode);

        // Verify debt tokens were updated
        debtTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID")
        );
        assertEq(debtTokens.length, 1, "Should have one debt token");
        assertEq(debtTokens[0], debtToken1, "Should have stable debt token");
    }

    function test_swapBorrowRateMode_ShouldUpdateSwapFromStableToVariable()
        public
    {
        uint256 interestRateMode = 2; // variable rate

        // First add stable debt token to held tokens
        address[] memory debtTokens = new address[](1);
        debtTokens[0] = debtToken1;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID"),
            debtTokens
        );

        // Mock swap rate mode
        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.swapBorrowRateMode.selector,
                token1,
                interestRateMode
            ),
            abi.encode()
        );

        vm.prank(facet);
        AaveV3Facet(facet).swapBorrowRateMode(pool, token1, interestRateMode);

        // Verify debt tokens were updated
        debtTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("MORE_DEBT_TOKENS_ID")
        );
        assertEq(debtTokens.length, 1, "Should have one debt token");
        assertEq(debtTokens[0], debtToken2, "Should have variable debt token");
    }

    function test_rebalanceStableBorrowRate_ShouldCallPool() public {
        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.rebalanceStableBorrowRate.selector,
                token1,
                address(this)
            ),
            abi.encode()
        );

        vm.prank(facet);
        AaveV3Facet(facet).rebalanceStableBorrowRate(
            pool,
            token1,
            address(this)
        );
    }

    function test_setUserUseReserveAsCollateral_ShouldCallPool() public {
        bool useAsCollateral = true;

        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.setUserUseReserveAsCollateral.selector,
                token1,
                useAsCollateral
            ),
            abi.encode()
        );

        vm.prank(facet);
        AaveV3Facet(facet).setUserUseReserveAsCollateral(
            pool,
            token1,
            useAsCollateral
        );
    }

    function test_flashLoan_ShouldCallPool() public {
        address[] memory assets = new address[](1);
        assets[0] = token1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e18;
        uint256[] memory interestRateModes = new uint256[](1);
        interestRateModes[0] = 0;
        bytes memory params = "";

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                address(this)
            ),
            abi.encode(true)
        );

        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.flashLoan.selector,
                address(this),
                assets,
                amounts,
                interestRateModes,
                address(this),
                params,
                0
            ),
            abi.encode()
        );

        vm.prank(facet);
        AaveV3Facet(facet).flashLoan(
            pool,
            address(this),
            assets,
            amounts,
            interestRateModes,
            address(this),
            params,
            0
        );
    }

    function test_flashLoan_ShouldRevertIfCreatedDebtInNonAvailableAsset()
        public
    {
        address[] memory assets = new address[](1);
        assets[0] = address(0x123); // Unsupported asset
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e18;
        uint256[] memory interestRateModes = new uint256[](1);
        interestRateModes[0] = 1;
        bytes memory params = "";

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                address(facet)
            ),
            abi.encode(true)
        );

        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.flashLoan.selector,
                address(facet),
                assets,
                amounts,
                interestRateModes,
                address(facet),
                params,
                0
            ),
            abi.encode()
        );

        vm.prank(facet);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAaveV3Facet.UnsupportedAsset.selector,
                assets[0]
            )
        );
        AaveV3Facet(facet).flashLoan(
            pool,
            address(facet),
            assets,
            amounts,
            interestRateModes,
            address(facet),
            params,
            0
        );
    }

    function test_flashLoanSimple_ShouldCallPool() public {
        uint256 amount = 1e18;
        bytes memory params = "";

        vm.mockCall(
            pool,
            abi.encodeWithSelector(
                IPool.flashLoanSimple.selector,
                address(this),
                token1,
                amount,
                params,
                0
            ),
            abi.encode()
        );

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                address(this)
            ),
            abi.encode(true)
        );

        vm.prank(facet);
        AaveV3Facet(facet).flashLoanSimple(
            pool,
            address(this),
            token1,
            amount,
            params,
            0
        );
    }

    function test_setUserEMode_ShouldCallPool() public {
        uint8 categoryId = 1;

        vm.mockCall(
            pool,
            abi.encodeWithSelector(IPool.setUserEMode.selector, categoryId),
            abi.encode()
        );

        vm.prank(facet);
        AaveV3Facet(facet).setUserEMode(pool, categoryId);
    }

    function test_claimAllRewards_ShouldCallRewardsController() public {
        address[] memory assets = new address[](1);
        assets[0] = token1;
        address[] memory rewardsList = new address[](1);
        rewardsList[0] = token2;
        uint256[] memory claimedAmounts = new uint256[](1);
        claimedAmounts[0] = 1e18;

        vm.mockCall(
            rewardsController,
            abi.encodeWithSelector(
                IAaveV3RewardsController.claimAllRewards.selector,
                assets,
                address(facet)
            ),
            abi.encode(rewardsList, claimedAmounts)
        );

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                rewardsController
            ),
            abi.encode(true)
        );

        vm.prank(facet);
        (
            address[] memory actualRewardsList,
            uint256[] memory actualClaimedAmounts
        ) = AaveV3Facet(facet).claimAllRewards(rewardsController, assets);

        assertEq(actualRewardsList.length, 1, "Should have one reward");
        assertEq(
            actualRewardsList[0],
            token2,
            "Should have correct reward token"
        );
        assertEq(actualClaimedAmounts.length, 1, "Should have one amount");
        assertEq(actualClaimedAmounts[0], 1e18, "Should have correct amount");
    }

    function test_claimAllRewards_ShouldRevertWithUnsupportedAsset() public {
        address[] memory assets = new address[](1);
        assets[0] = address(0x123); // Unsupported asset

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                rewardsController
            ),
            abi.encode(true)
        );

        vm.prank(facet);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAaveV3Facet.UnsupportedAsset.selector,
                assets[0]
            )
        );
        AaveV3Facet(facet).claimAllRewards(rewardsController, assets);
    }
}

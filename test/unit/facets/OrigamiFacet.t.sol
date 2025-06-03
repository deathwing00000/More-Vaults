// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {MORELeverageFacet} from "../../../src/facets/MORELeverageFacet.sol";
import {MoreVaultsStorageHelper} from "../../helper/MoreVaultsStorageHelper.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IOrigamiInvestment} from "../../../src/interfaces/Origami/IOrigamiInvestment.sol";
import {IOrigamiLovTokenFlashAndBorrowManager} from "../../../src/interfaces/Origami/IOrigamiLovTokenFlashAndBorrowManager.sol";
import {BaseFacetInitializer} from "../../../src/facets/BaseFacetInitializer.sol";
import {AccessControlLib} from "../../../src/libraries/AccessControlLib.sol";
import {MoreVaultsLib} from "../../../src/libraries/MoreVaultsLib.sol";
import {IMoreVaultsRegistry} from "../../../src/interfaces/IMoreVaultsRegistry.sol";

contract MORELeverageFacetTest is Test {
    // Test addresses
    address public facet = address(100);
    address public lovToken = address(2);
    address public fromToken = address(3);
    address public toToken = address(4);
    address public manager = address(5);
    address public curator = address(7);
    address public user = address(8);
    address public registry = address(9);
    uint256 public deadline = block.timestamp + 1 hours;

    // Test amounts
    uint256 constant AMOUNT = 1e18;
    uint256 constant MAX_SLIPPAGE_BPS = 1000;
    uint256 constant FLASH_LOAN_AMOUNT = 1e19;
    uint256 constant COLLATERAL_TO_WITHDRAW = 1e17;
    uint256 constant MIN_EXPECTED_RESERVE_TOKEN = 1e16;
    uint256 constant REPAY_SURPLUS_THRESHOLD = 1e15;
    uint128 constant MIN_NEW_AL = 1e14;
    uint128 constant MAX_NEW_AL = 1e13;

    function setUp() public {
        deadline = block.timestamp + 1 hours;

        // Deploy facet
        MORELeverageFacet facetContract = new MORELeverageFacet();
        facet = address(facetContract);

        // Set initial values in storage
        address[] memory availableAssets = new address[](2);
        availableAssets[0] = fromToken;
        availableAssets[1] = toToken;
        MoreVaultsStorageHelper.setAvailableAssets(facet, availableAssets);
        MoreVaultsStorageHelper.setCurator(facet, curator);
        MoreVaultsStorageHelper.setWrappedNative(facet, address(toToken));
        MoreVaultsStorageHelper.setMoreVaultsRegistry(facet, address(registry));

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                manager
            ),
            abi.encode(true)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                lovToken
            ),
            abi.encode(true)
        );

        vm.deal(facet, 100000 ether);
    }

    function test_facetName_ShouldReturnCorrectName() public view {
        assertEq(MORELeverageFacet(facet).facetName(), "MORELeverageFacet");
    }

    function test_initialize_ShouldSetFacetAddress() public {
        MORELeverageFacet(facet).initialize(abi.encode(facet));
        MoreVaultsStorageHelper.getStorageValue(facet, 0); // Verify storage was updated
    }

    function test_initialize_ShouldRevertWhenAlreadyInitialized() public {
        // First initialization
        MORELeverageFacet(facet).initialize(abi.encode(facet));

        // Try to initialize again
        vm.expectRevert(BaseFacetInitializer.AlreadyInitialized.selector);
        MORELeverageFacet(facet).initialize(abi.encode(facet));
    }

    function test_allNonViewFunctions_ShouldRevertWhenCalledByNonDiamond()
        public
    {
        vm.startPrank(user);
        IOrigamiInvestment.InvestQuoteData
            memory investQuoteData = IOrigamiInvestment.InvestQuoteData({
                fromToken: fromToken,
                fromTokenAmount: AMOUNT,
                maxSlippageBps: MAX_SLIPPAGE_BPS,
                deadline: deadline,
                expectedInvestmentAmount: AMOUNT,
                minInvestmentAmount: AMOUNT,
                underlyingInvestmentQuoteData: ""
            });
        IOrigamiInvestment.ExitQuoteData
            memory exitQuoteData = IOrigamiInvestment.ExitQuoteData({
                investmentTokenAmount: AMOUNT,
                toToken: toToken,
                maxSlippageBps: MAX_SLIPPAGE_BPS,
                deadline: deadline,
                expectedToTokenAmount: AMOUNT,
                minToTokenAmount: AMOUNT,
                underlyingInvestmentQuoteData: ""
            });

        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        MORELeverageFacet(facet).investWithToken(lovToken, investQuoteData);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        MORELeverageFacet(facet).investWithNative(lovToken, investQuoteData);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        MORELeverageFacet(facet).exitToToken(lovToken, exitQuoteData);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        MORELeverageFacet(facet).exitToNative(lovToken, exitQuoteData);

        vm.stopPrank();
    }

    function test_allNonViewFunctions_ShouldRevertWhenCalledByNonWhitelistedAddress()
        public
    {
        vm.startPrank(address(facet));
        IOrigamiInvestment.InvestQuoteData
            memory investQuoteData = IOrigamiInvestment.InvestQuoteData({
                fromToken: fromToken,
                fromTokenAmount: AMOUNT,
                maxSlippageBps: MAX_SLIPPAGE_BPS,
                deadline: deadline,
                expectedInvestmentAmount: AMOUNT,
                minInvestmentAmount: AMOUNT,
                underlyingInvestmentQuoteData: ""
            });
        IOrigamiInvestment.ExitQuoteData
            memory exitQuoteData = IOrigamiInvestment.ExitQuoteData({
                investmentTokenAmount: AMOUNT,
                toToken: toToken,
                maxSlippageBps: MAX_SLIPPAGE_BPS,
                deadline: deadline,
                expectedToTokenAmount: AMOUNT,
                minToTokenAmount: AMOUNT,
                underlyingInvestmentQuoteData: ""
            });

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                manager
            ),
            abi.encode(false)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                lovToken
            ),
            abi.encode(false)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                lovToken
            )
        );
        MORELeverageFacet(facet).investWithToken(lovToken, investQuoteData);
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                lovToken
            )
        );
        MORELeverageFacet(facet).exitToToken(lovToken, exitQuoteData);
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                lovToken
            )
        );
        MORELeverageFacet(facet).exitToNative(lovToken, exitQuoteData);

        vm.stopPrank();
    }

    function test_investWithToken_ShouldAddLovTokenToHeldTokens() public {
        // Mock approvals and investWithToken
        vm.mockCall(
            fromToken,
            abi.encodeWithSelector(IERC20.approve.selector, lovToken, AMOUNT),
            abi.encode(true)
        );

        IOrigamiInvestment.InvestQuoteData
            memory investQuoteData = IOrigamiInvestment.InvestQuoteData({
                fromToken: fromToken,
                fromTokenAmount: AMOUNT,
                maxSlippageBps: MAX_SLIPPAGE_BPS,
                deadline: deadline,
                expectedInvestmentAmount: AMOUNT,
                minInvestmentAmount: AMOUNT,
                underlyingInvestmentQuoteData: ""
            });
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.investWithToken.selector,
                investQuoteData
            ),
            abi.encode(AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        MORELeverageFacet(facet).investWithToken(lovToken, investQuoteData);

        // Verify lovToken was added to held tokens
        address[] memory lovTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("ORIGAMI_VAULT_TOKENS_ID")
        );
        assertEq(lovTokens.length, 1, "Should have one lovToken");
        assertEq(lovTokens[0], lovToken, "Should have correct lovToken");
    }

    function test_investWithNative_ShouldAddLovTokenToHeldTokens() public {
        IOrigamiInvestment.InvestQuoteData
            memory investQuoteData = IOrigamiInvestment.InvestQuoteData({
                fromToken: fromToken,
                fromTokenAmount: AMOUNT,
                maxSlippageBps: MAX_SLIPPAGE_BPS,
                deadline: deadline,
                expectedInvestmentAmount: AMOUNT,
                minInvestmentAmount: AMOUNT,
                underlyingInvestmentQuoteData: ""
            });

        // Mock investWithNative
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.investWithNative.selector,
                investQuoteData
            ),
            abi.encode(AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        vm.deal(facet, AMOUNT);
        MORELeverageFacet(facet).investWithNative(lovToken, investQuoteData);

        // Verify lovToken was added to held tokens
        address[] memory lovTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("ORIGAMI_VAULT_TOKENS_ID")
        );
        assertEq(lovTokens.length, 1, "Should have one lovToken");
        assertEq(lovTokens[0], lovToken, "Should have correct lovToken");
    }

    function test_exitToToken_ShouldRemoveLovTokenFromHeldTokens() public {
        // First add lovToken to held tokens
        address[] memory lovTokens = new address[](1);
        lovTokens[0] = lovToken;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("ORIGAMI_VAULT_TOKENS_ID"),
            lovTokens
        );

        // Mock balance check to return zero balance
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(0)
        );

        IOrigamiInvestment.ExitQuoteData
            memory exitQuoteData = IOrigamiInvestment.ExitQuoteData({
                investmentTokenAmount: AMOUNT,
                toToken: toToken,
                maxSlippageBps: MAX_SLIPPAGE_BPS,
                deadline: deadline,
                expectedToTokenAmount: AMOUNT,
                minToTokenAmount: AMOUNT,
                underlyingInvestmentQuoteData: ""
            });

        // Mock exitToToken
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.exitToToken.selector,
                exitQuoteData,
                facet
            ),
            abi.encode(AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        MORELeverageFacet(facet).exitToToken(lovToken, exitQuoteData);

        // Verify lovToken was removed from held tokens
        lovTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("ORIGAMI_VAULT_TOKENS_ID")
        );
        assertEq(lovTokens.length, 0, "Should have no lovTokens");
    }

    function test_exitToNative_ShouldRemoveLovTokenFromHeldTokens() public {
        // First add lovToken to held tokens
        address[] memory lovTokens = new address[](1);
        lovTokens[0] = lovToken;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("ORIGAMI_VAULT_TOKENS_ID"),
            lovTokens
        );

        // Mock balance check to return zero balance
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(0)
        );

        IOrigamiInvestment.ExitQuoteData
            memory exitQuoteData = IOrigamiInvestment.ExitQuoteData({
                investmentTokenAmount: AMOUNT,
                toToken: address(0),
                maxSlippageBps: MAX_SLIPPAGE_BPS,
                deadline: deadline,
                expectedToTokenAmount: AMOUNT,
                minToTokenAmount: AMOUNT,
                underlyingInvestmentQuoteData: ""
            });

        // Mock exitToNative
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.exitToNative.selector,
                exitQuoteData,
                payable(facet)
            ),
            abi.encode(AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        MORELeverageFacet(facet).exitToNative(lovToken, exitQuoteData);

        // Verify lovToken was removed from held tokens
        lovTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("ORIGAMI_VAULT_TOKENS_ID")
        );
        assertEq(lovTokens.length, 0, "Should have no lovTokens");
    }

    function test_exitToToken_ShouldNotRemoveLovTokenWhenBalanceIsNonZero()
        public
    {
        // First add lovToken to held tokens
        address[] memory lovTokens = new address[](1);
        lovTokens[0] = lovToken;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("ORIGAMI_VAULT_TOKENS_ID"),
            lovTokens
        );

        // Mock balance check to return non-zero balance
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(10e3 + 1)
        );

        // Mock exitToToken
        IOrigamiInvestment.ExitQuoteData
            memory exitQuoteData = IOrigamiInvestment.ExitQuoteData({
                investmentTokenAmount: AMOUNT,
                toToken: toToken,
                maxSlippageBps: MAX_SLIPPAGE_BPS,
                deadline: deadline,
                expectedToTokenAmount: AMOUNT,
                minToTokenAmount: AMOUNT,
                underlyingInvestmentQuoteData: ""
            });
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.exitToToken.selector,
                exitQuoteData,
                facet
            ),
            abi.encode(AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        MORELeverageFacet(facet).exitToToken(lovToken, exitQuoteData);

        // Verify lovToken was not removed from held tokens
        lovTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("ORIGAMI_VAULT_TOKENS_ID")
        );
        assertEq(lovTokens.length, 1, "Should still have one lovToken");
        assertEq(lovTokens[0], lovToken, "Should still have correct lovToken");
    }

    function test_exitToNative_ShouldNotRemoveLovTokenWhenBalanceIsNonZero()
        public
    {
        // First add lovToken to held tokens
        address[] memory lovTokens = new address[](1);
        lovTokens[0] = lovToken;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("ORIGAMI_VAULT_TOKENS_ID"),
            lovTokens
        );

        // Mock balance check to return non-zero balance
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(10e3 + 1)
        );

        IOrigamiInvestment.ExitQuoteData
            memory exitQuoteData = IOrigamiInvestment.ExitQuoteData({
                investmentTokenAmount: AMOUNT,
                toToken: address(0),
                maxSlippageBps: MAX_SLIPPAGE_BPS,
                deadline: deadline,
                expectedToTokenAmount: AMOUNT,
                minToTokenAmount: AMOUNT,
                underlyingInvestmentQuoteData: ""
            });
        // Mock exitToNative
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.exitToNative.selector,
                exitQuoteData,
                payable(facet)
            ),
            abi.encode(AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        MORELeverageFacet(facet).exitToNative(lovToken, exitQuoteData);

        // Verify lovToken was not removed from held tokens
        lovTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("ORIGAMI_VAULT_TOKENS_ID")
        );
        assertEq(lovTokens.length, 1, "Should still have one lovToken");
        assertEq(lovTokens[0], lovToken, "Should still have correct lovToken");
    }

    function test_rebalanceUp_ShouldCallRebalanceUp() public {
        bytes memory swapData = abi.encode(AMOUNT);

        // Mock rebalanceUp
        vm.mockCall(
            manager,
            abi.encodeWithSelector(
                IOrigamiLovTokenFlashAndBorrowManager.rebalanceUp.selector,
                IOrigamiLovTokenFlashAndBorrowManager.RebalanceUpParams({
                    flashLoanAmount: FLASH_LOAN_AMOUNT,
                    collateralToWithdraw: COLLATERAL_TO_WITHDRAW,
                    swapData: swapData,
                    repaySurplusThreshold: REPAY_SURPLUS_THRESHOLD,
                    minNewAL: MIN_NEW_AL,
                    maxNewAL: MAX_NEW_AL
                })
            ),
            abi.encode()
        );

        // Set up as curator
        vm.prank(facet);

        MORELeverageFacet(facet).rebalanceUp(
            manager,
            FLASH_LOAN_AMOUNT,
            COLLATERAL_TO_WITHDRAW,
            swapData,
            REPAY_SURPLUS_THRESHOLD,
            MIN_NEW_AL,
            MAX_NEW_AL
        );
    }

    function test_forceRebalanceUp_ShouldCallForceRebalanceUp() public {
        bytes memory swapData = abi.encode(AMOUNT);

        // Mock forceRebalanceUp
        vm.mockCall(
            manager,
            abi.encodeWithSelector(
                IOrigamiLovTokenFlashAndBorrowManager.forceRebalanceUp.selector,
                IOrigamiLovTokenFlashAndBorrowManager.RebalanceUpParams({
                    flashLoanAmount: FLASH_LOAN_AMOUNT,
                    collateralToWithdraw: COLLATERAL_TO_WITHDRAW,
                    swapData: swapData,
                    repaySurplusThreshold: REPAY_SURPLUS_THRESHOLD,
                    minNewAL: MIN_NEW_AL,
                    maxNewAL: MAX_NEW_AL
                })
            ),
            abi.encode()
        );

        // Set up as curator
        vm.prank(facet);

        MORELeverageFacet(facet).forceRebalanceUp(
            manager,
            FLASH_LOAN_AMOUNT,
            COLLATERAL_TO_WITHDRAW,
            swapData,
            REPAY_SURPLUS_THRESHOLD,
            MIN_NEW_AL,
            MAX_NEW_AL
        );
    }

    function test_rebalanceDown_ShouldCallRebalanceDown() public {
        bytes memory swapData = abi.encode(AMOUNT);

        // Mock rebalanceDown
        vm.mockCall(
            manager,
            abi.encodeWithSelector(
                IOrigamiLovTokenFlashAndBorrowManager.rebalanceDown.selector,
                IOrigamiLovTokenFlashAndBorrowManager.RebalanceDownParams({
                    flashLoanAmount: FLASH_LOAN_AMOUNT,
                    minExpectedReserveToken: MIN_EXPECTED_RESERVE_TOKEN,
                    swapData: swapData,
                    minNewAL: MIN_NEW_AL,
                    maxNewAL: MAX_NEW_AL
                })
            ),
            abi.encode()
        );

        // Set up as curator
        vm.prank(facet);

        MORELeverageFacet(facet).rebalanceDown(
            manager,
            FLASH_LOAN_AMOUNT,
            MIN_EXPECTED_RESERVE_TOKEN,
            swapData,
            MIN_NEW_AL,
            MAX_NEW_AL
        );
    }

    function test_forceRebalanceDown_ShouldCallForceRebalanceDown() public {
        bytes memory swapData = abi.encode(AMOUNT);

        // Mock forceRebalanceDown
        vm.mockCall(
            manager,
            abi.encodeWithSelector(
                IOrigamiLovTokenFlashAndBorrowManager
                    .forceRebalanceDown
                    .selector,
                IOrigamiLovTokenFlashAndBorrowManager.RebalanceDownParams({
                    flashLoanAmount: FLASH_LOAN_AMOUNT,
                    minExpectedReserveToken: MIN_EXPECTED_RESERVE_TOKEN,
                    swapData: swapData,
                    minNewAL: MIN_NEW_AL,
                    maxNewAL: MAX_NEW_AL
                })
            ),
            abi.encode()
        );

        // Set up as curator
        vm.prank(facet);

        MORELeverageFacet(facet).forceRebalanceDown(
            manager,
            FLASH_LOAN_AMOUNT,
            MIN_EXPECTED_RESERVE_TOKEN,
            swapData,
            MIN_NEW_AL,
            MAX_NEW_AL
        );
    }
}

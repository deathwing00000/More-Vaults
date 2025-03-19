// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {OrigamiFacet} from "../../src/facets/OrigamiFacet.sol";
import {MoreVaultsStorageHelper} from "../libraries/MoreVaultsStorageHelper.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IOrigamiInvestment} from "../../src/interfaces/Origami/IOrigamiInvestment.sol";
import {IOrigamiLovTokenFlashAndBorrowManager} from "../../src/interfaces/Origami/IOrigamiLovTokenFlashAndBorrowManager.sol";
import {BaseFacetInitializer} from "../../src/facets/BaseFacetInitializer.sol";

contract OrigamiFacetTest is Test {
    // Test addresses
    address public facet = address(100);
    address public lovToken = address(2);
    address public fromToken = address(3);
    address public toToken = address(4);
    address public manager = address(5);
    address public curator = address(7);
    address public user = address(8);
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
        OrigamiFacet facetContract = new OrigamiFacet();
        facet = address(facetContract);

        // Set initial values in storage
        address[] memory availableAssets = new address[](2);
        availableAssets[0] = fromToken;
        availableAssets[1] = toToken;
        MoreVaultsStorageHelper.setAvailableAssets(facet, availableAssets);
        MoreVaultsStorageHelper.setCurator(facet, curator);

        vm.deal(facet, 100000 ether);
    }

    function test_initialize_ShouldSetFacetAddress() public {
        OrigamiFacet(facet).initialize(abi.encode(facet));
        MoreVaultsStorageHelper.getStorageValue(facet, 0); // Verify storage was updated
    }

    function test_initialize_ShouldRevertWhenAlreadyInitialized() public {
        // First initialization
        OrigamiFacet(facet).initialize(abi.encode(facet));

        // Try to initialize again
        vm.expectRevert(BaseFacetInitializer.AlreadyInitialized.selector);
        OrigamiFacet(facet).initialize(abi.encode(facet));
    }

    function test_investWithToken_ShouldAddLovTokenToHeldTokens() public {
        // Mock approvals and investWithToken
        vm.mockCall(
            fromToken,
            abi.encodeWithSelector(IERC20.approve.selector, lovToken, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.investQuote.selector,
                AMOUNT,
                fromToken,
                MAX_SLIPPAGE_BPS,
                deadline
            ),
            abi.encode(
                IOrigamiInvestment.InvestQuoteData({
                    fromToken: fromToken,
                    fromTokenAmount: AMOUNT,
                    maxSlippageBps: MAX_SLIPPAGE_BPS,
                    deadline: deadline,
                    expectedInvestmentAmount: AMOUNT,
                    minInvestmentAmount: AMOUNT,
                    underlyingInvestmentQuoteData: ""
                }),
                new uint256[](0)
            )
        );
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.investWithToken.selector,
                IOrigamiInvestment.InvestQuoteData({
                    fromToken: fromToken,
                    fromTokenAmount: AMOUNT,
                    maxSlippageBps: MAX_SLIPPAGE_BPS,
                    deadline: deadline,
                    expectedInvestmentAmount: AMOUNT,
                    minInvestmentAmount: AMOUNT,
                    underlyingInvestmentQuoteData: ""
                })
            ),
            abi.encode(AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        OrigamiFacet(facet).investWithToken(
            lovToken,
            AMOUNT,
            fromToken,
            MAX_SLIPPAGE_BPS,
            deadline
        );

        // Verify lovToken was added to held tokens
        address[] memory lovTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("ORIGAMI_VAULT_TOKENS_ID")
        );
        assertEq(lovTokens.length, 1, "Should have one lovToken");
        assertEq(lovTokens[0], lovToken, "Should have correct lovToken");
    }

    function test_investWithNative_ShouldAddLovTokenToHeldTokens() public {
        // Mock investWithNative
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.investQuote.selector,
                AMOUNT,
                fromToken,
                MAX_SLIPPAGE_BPS,
                deadline
            ),
            abi.encode(
                IOrigamiInvestment.InvestQuoteData({
                    fromToken: fromToken,
                    fromTokenAmount: AMOUNT,
                    maxSlippageBps: MAX_SLIPPAGE_BPS,
                    deadline: deadline,
                    expectedInvestmentAmount: AMOUNT,
                    minInvestmentAmount: AMOUNT,
                    underlyingInvestmentQuoteData: ""
                }),
                new uint256[](0)
            )
        );
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.investWithNative.selector,
                IOrigamiInvestment.InvestQuoteData({
                    fromToken: fromToken,
                    fromTokenAmount: AMOUNT,
                    maxSlippageBps: MAX_SLIPPAGE_BPS,
                    deadline: deadline,
                    expectedInvestmentAmount: AMOUNT,
                    minInvestmentAmount: AMOUNT,
                    underlyingInvestmentQuoteData: ""
                })
            ),
            abi.encode(AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        OrigamiFacet(facet).investWithNative{value: AMOUNT}(
            lovToken,
            AMOUNT,
            fromToken,
            MAX_SLIPPAGE_BPS,
            deadline
        );

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

        // Mock exitToToken
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.exitQuote.selector,
                AMOUNT,
                toToken,
                MAX_SLIPPAGE_BPS,
                deadline
            ),
            abi.encode(
                IOrigamiInvestment.ExitQuoteData({
                    investmentTokenAmount: AMOUNT,
                    toToken: toToken,
                    maxSlippageBps: MAX_SLIPPAGE_BPS,
                    deadline: deadline,
                    expectedToTokenAmount: AMOUNT,
                    minToTokenAmount: AMOUNT,
                    underlyingInvestmentQuoteData: ""
                }),
                new uint256[](0)
            )
        );
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.exitToToken.selector,
                IOrigamiInvestment.ExitQuoteData({
                    investmentTokenAmount: AMOUNT,
                    toToken: toToken,
                    maxSlippageBps: MAX_SLIPPAGE_BPS,
                    deadline: deadline,
                    expectedToTokenAmount: AMOUNT,
                    minToTokenAmount: AMOUNT,
                    underlyingInvestmentQuoteData: ""
                }),
                facet
            ),
            abi.encode(AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        OrigamiFacet(facet).exitToToken(
            lovToken,
            AMOUNT,
            toToken,
            MAX_SLIPPAGE_BPS,
            deadline
        );

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

        // Mock exitToNative
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.exitQuote.selector,
                AMOUNT,
                toToken,
                MAX_SLIPPAGE_BPS,
                deadline
            ),
            abi.encode(
                IOrigamiInvestment.ExitQuoteData({
                    investmentTokenAmount: AMOUNT,
                    toToken: toToken,
                    maxSlippageBps: MAX_SLIPPAGE_BPS,
                    deadline: deadline,
                    expectedToTokenAmount: AMOUNT,
                    minToTokenAmount: AMOUNT,
                    underlyingInvestmentQuoteData: ""
                }),
                new uint256[](0)
            )
        );
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.exitToNative.selector,
                IOrigamiInvestment.ExitQuoteData({
                    investmentTokenAmount: AMOUNT,
                    toToken: toToken,
                    maxSlippageBps: MAX_SLIPPAGE_BPS,
                    deadline: deadline,
                    expectedToTokenAmount: AMOUNT,
                    minToTokenAmount: AMOUNT,
                    underlyingInvestmentQuoteData: ""
                }),
                payable(facet)
            ),
            abi.encode(AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        OrigamiFacet(facet).exitToNative(
            lovToken,
            AMOUNT,
            toToken,
            MAX_SLIPPAGE_BPS,
            deadline
        );

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
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.exitQuote.selector,
                AMOUNT,
                toToken,
                MAX_SLIPPAGE_BPS,
                deadline
            ),
            abi.encode(
                IOrigamiInvestment.ExitQuoteData({
                    investmentTokenAmount: AMOUNT,
                    toToken: toToken,
                    maxSlippageBps: MAX_SLIPPAGE_BPS,
                    deadline: deadline,
                    expectedToTokenAmount: AMOUNT,
                    minToTokenAmount: AMOUNT,
                    underlyingInvestmentQuoteData: ""
                }),
                new uint256[](0)
            )
        );
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.exitToToken.selector,
                IOrigamiInvestment.ExitQuoteData({
                    investmentTokenAmount: AMOUNT,
                    toToken: toToken,
                    maxSlippageBps: MAX_SLIPPAGE_BPS,
                    deadline: deadline,
                    expectedToTokenAmount: AMOUNT,
                    minToTokenAmount: AMOUNT,
                    underlyingInvestmentQuoteData: ""
                }),
                facet
            ),
            abi.encode(AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        OrigamiFacet(facet).exitToToken(
            lovToken,
            AMOUNT,
            toToken,
            MAX_SLIPPAGE_BPS,
            deadline
        );

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

        // Mock exitToNative
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.exitQuote.selector,
                AMOUNT,
                toToken,
                MAX_SLIPPAGE_BPS,
                deadline
            ),
            abi.encode(
                IOrigamiInvestment.ExitQuoteData({
                    investmentTokenAmount: AMOUNT,
                    toToken: toToken,
                    maxSlippageBps: MAX_SLIPPAGE_BPS,
                    deadline: deadline,
                    expectedToTokenAmount: AMOUNT,
                    minToTokenAmount: AMOUNT,
                    underlyingInvestmentQuoteData: ""
                }),
                new uint256[](0)
            )
        );
        vm.mockCall(
            lovToken,
            abi.encodeWithSelector(
                IOrigamiInvestment.exitToNative.selector,
                IOrigamiInvestment.ExitQuoteData({
                    investmentTokenAmount: AMOUNT,
                    toToken: toToken,
                    maxSlippageBps: MAX_SLIPPAGE_BPS,
                    deadline: deadline,
                    expectedToTokenAmount: AMOUNT,
                    minToTokenAmount: AMOUNT,
                    underlyingInvestmentQuoteData: ""
                }),
                payable(facet)
            ),
            abi.encode(AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        OrigamiFacet(facet).exitToNative(
            lovToken,
            AMOUNT,
            toToken,
            MAX_SLIPPAGE_BPS,
            deadline
        );

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

        OrigamiFacet(facet).rebalanceUp(
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

        OrigamiFacet(facet).forceRebalanceUp(
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

        OrigamiFacet(facet).rebalanceDown(
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

        OrigamiFacet(facet).forceRebalanceDown(
            manager,
            FLASH_LOAN_AMOUNT,
            MIN_EXPECTED_RESERVE_TOKEN,
            swapData,
            MIN_NEW_AL,
            MAX_NEW_AL
        );
    }
}

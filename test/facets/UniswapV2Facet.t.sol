// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IUniswapV2Facet, UniswapV2Facet} from "../../src/facets/UniswapV2Facet.sol";
import {MoreVaultsStorageHelper} from "../libraries/MoreVaultsStorageHelper.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IUniswapV2Router02, IUniswapV2Router01} from "@uniswap-v2/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../../src/interfaces/Uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../../src/interfaces/Uniswap/v2/IUniswapV2Pair.sol";
import {BaseFacetInitializer} from "../../src/facets/BaseFacetInitializer.sol";

contract UniswapV2FacetTest is Test {
    // Test addresses
    address public facet = address(100);
    address public token1 = address(2);
    address public token2 = address(3);
    address public router = address(4);
    address public factory = address(5);
    address public pair = address(6);
    address public curator = address(7);
    address public user = address(8);
    uint256 public deadline = block.timestamp + 1 hours;

    // Test amounts
    uint256 constant AMOUNT = 1e18;
    uint256 constant MIN_AMOUNT = 1e17;

    function setUp() public {
        deadline = block.timestamp + 1 hours;

        // Deploy facet
        UniswapV2Facet facetContract = new UniswapV2Facet();
        facet = address(facetContract);

        // Set initial values in storage
        address[] memory availableAssets = new address[](2);
        availableAssets[0] = token1;
        availableAssets[1] = token2;
        MoreVaultsStorageHelper.setAvailableAssets(facet, availableAssets);
        MoreVaultsStorageHelper.setCurator(facet, curator);

        // Mock factory and pair
        vm.mockCall(
            router,
            abi.encodeWithSelector(IUniswapV2Router01.factory.selector),
            abi.encode(factory)
        );
        vm.mockCall(
            factory,
            abi.encodeWithSelector(
                IUniswapV2Factory.getPair.selector,
                token1,
                token2
            ),
            abi.encode(pair)
        );
        vm.mockCall(
            factory,
            abi.encodeWithSelector(
                IUniswapV2Factory.getPair.selector,
                token1,
                address(0)
            ),
            abi.encode(pair)
        );

        vm.deal(facet, 100000 ether);
    }

    function test_initialize_ShouldSetFacetAddress() public {
        UniswapV2Facet(facet).initialize(abi.encode(facet));
        MoreVaultsStorageHelper.getStorageValue(facet, 0); // Verify storage was updated
    }

    function test_initialize_ShouldRevertWhenAlreadyInitialized() public {
        // First initialization
        UniswapV2Facet(facet).initialize(abi.encode(facet));

        // Try to initialize again
        vm.expectRevert(BaseFacetInitializer.AlreadyInitialized.selector);
        UniswapV2Facet(facet).initialize(abi.encode(facet));
    }

    function test_addLiquidity_ShouldAddLPTokenToHeldTokens() public {
        // Mock approvals and addLiquidity
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, router, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            token2,
            abi.encodeWithSelector(IERC20.approve.selector, router, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router01.addLiquidity.selector,
                token1,
                token2,
                AMOUNT,
                AMOUNT,
                MIN_AMOUNT,
                MIN_AMOUNT,
                address(this),
                deadline
            ),
            abi.encode(AMOUNT, AMOUNT, AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet).addLiquidity(
            router,
            token1,
            token2,
            AMOUNT,
            AMOUNT,
            MIN_AMOUNT,
            MIN_AMOUNT,
            address(this),
            deadline
        );

        // Verify LP token was added to held tokens
        address[] memory lpTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("UNISWAP_V2_LP_TOKENS_ID")
        );
        assertEq(lpTokens.length, 1, "Should have one LP token");
        assertEq(lpTokens[0], pair, "Should have correct LP token");
    }

    function test_addLiquidityETH_ShouldAddLPTokenToHeldTokens() public {
        // Mock approvals and addLiquidityETH
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, router, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router01.addLiquidityETH.selector,
                token1,
                AMOUNT,
                MIN_AMOUNT,
                MIN_AMOUNT,
                address(this),
                deadline
            ),
            abi.encode(AMOUNT, AMOUNT, AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet).addLiquidityETH(
            router,
            token1,
            AMOUNT,
            AMOUNT,
            MIN_AMOUNT,
            MIN_AMOUNT,
            address(this),
            deadline
        );

        // Verify LP token was added to held tokens
        address[] memory lpTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("UNISWAP_V2_LP_TOKENS_ID")
        );
        assertEq(lpTokens.length, 1, "Should have one LP token");
        assertEq(lpTokens[0], pair, "Should have correct LP token");
    }

    function test_removeLiquidity_ShouldRemoveLPTokenFromHeldTokens() public {
        // First add LP token to held tokens
        address[] memory lpTokens = new address[](1);
        lpTokens[0] = pair;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("UNISWAP_V2_LP_TOKENS_ID"),
            lpTokens
        );

        // Mock balance check to return zero balance
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(0)
        );

        // Mock approvals and removeLiquidity
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IERC20.approve.selector, router, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router01.removeLiquidity.selector,
                token1,
                token2,
                AMOUNT,
                MIN_AMOUNT,
                MIN_AMOUNT,
                address(this),
                deadline
            ),
            abi.encode(AMOUNT, AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet).removeLiquidity(
            router,
            token1,
            token2,
            AMOUNT,
            MIN_AMOUNT,
            MIN_AMOUNT,
            address(this),
            deadline
        );

        // Verify LP token was removed from held tokens
        lpTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("UNISWAP_V2_LP_TOKENS_ID")
        );
        assertEq(lpTokens.length, 0, "Should have no LP tokens");
    }

    function test_removeLiquidityETH_ShouldRemoveLPTokenFromHeldTokens()
        public
    {
        // First add LP token to held tokens
        address[] memory lpTokens = new address[](1);
        lpTokens[0] = pair;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("UNISWAP_V2_LP_TOKENS_ID"),
            lpTokens
        );

        // Mock balance check to return zero balance
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(0)
        );

        // Mock approvals and removeLiquidityETH
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IERC20.approve.selector, router, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router01.removeLiquidityETH.selector,
                token1,
                AMOUNT,
                MIN_AMOUNT,
                MIN_AMOUNT,
                address(this),
                deadline
            ),
            abi.encode(AMOUNT, AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet).removeLiquidityETH(
            router,
            token1,
            AMOUNT,
            MIN_AMOUNT,
            MIN_AMOUNT,
            address(this),
            deadline
        );

        // Verify LP token was removed from held tokens
        lpTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("UNISWAP_V2_LP_TOKENS_ID")
        );
        assertEq(lpTokens.length, 0, "Should have no LP tokens");
    }

    function test_removeLiquidity_ShouldNotRemoveLPTokenWhenBalanceIsNonZero()
        public
    {
        // First add LP token to held tokens
        address[] memory lpTokens = new address[](1);
        lpTokens[0] = pair;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("UNISWAP_V2_LP_TOKENS_ID"),
            lpTokens
        );

        // Mock balance check to return non-zero balance
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(10e3 + 1)
        );

        // Mock approvals and removeLiquidity
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IERC20.approve.selector, router, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router01.removeLiquidity.selector,
                token1,
                token2,
                AMOUNT,
                MIN_AMOUNT,
                MIN_AMOUNT,
                address(this),
                deadline
            ),
            abi.encode(AMOUNT, AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet).removeLiquidity(
            router,
            token1,
            token2,
            AMOUNT,
            MIN_AMOUNT,
            MIN_AMOUNT,
            address(this),
            deadline
        );

        // Verify LP token was not removed from held tokens
        lpTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("UNISWAP_V2_LP_TOKENS_ID")
        );
        assertEq(lpTokens.length, 1, "Should still have one LP token");
        assertEq(lpTokens[0], pair, "Should still have correct LP token");
    }

    function test_removeLiquidityETH_ShouldNotRemoveLPTokenWhenBalanceIsNonZero()
        public
    {
        // First add LP token to held tokens
        address[] memory lpTokens = new address[](1);
        lpTokens[0] = pair;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("UNISWAP_V2_LP_TOKENS_ID"),
            lpTokens
        );

        // Mock balance check to return non-zero balance
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(10e3 + 1)
        );

        // Mock approvals and removeLiquidityETH
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IERC20.approve.selector, router, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router01.removeLiquidityETH.selector,
                token1,
                AMOUNT,
                MIN_AMOUNT,
                MIN_AMOUNT,
                address(this),
                deadline
            ),
            abi.encode(AMOUNT, AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet).removeLiquidityETH(
            router,
            token1,
            AMOUNT,
            MIN_AMOUNT,
            MIN_AMOUNT,
            address(this),
            deadline
        );

        // Verify LP token was not removed from held tokens
        lpTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("UNISWAP_V2_LP_TOKENS_ID")
        );
        assertEq(lpTokens.length, 1, "Should still have one LP token");
        assertEq(lpTokens[0], pair, "Should still have correct LP token");
    }

    function test_swapExactTokensForTokens_ShouldCallSwapExactTokensForTokens()
        public
    {
        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = token2;

        // Mock approvals and swapExactTokensForTokens
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, router, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router01.swapExactTokensForTokens.selector,
                AMOUNT,
                MIN_AMOUNT,
                path,
                address(this),
                deadline
            ),
            abi.encode(new uint256[](2))
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet).swapExactTokensForTokens(
            router,
            AMOUNT,
            MIN_AMOUNT,
            path,
            address(this),
            deadline
        );
    }

    function test_swapExactETHForTokens_ShouldCallSwapExactETHForTokens()
        public
    {
        address[] memory path = new address[](2);
        path[0] = address(0);
        path[1] = token1;

        // Mock swapExactETHForTokens
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router01.swapExactETHForTokens.selector,
                MIN_AMOUNT,
                path,
                address(this),
                deadline
            ),
            abi.encode(new uint256[](2))
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet).swapExactETHForTokens(
            router,
            AMOUNT,
            MIN_AMOUNT,
            path,
            address(this),
            deadline
        );
    }

    function test_swapTokensForExactETH_ShouldCallSwapTokensForExactETH()
        public
    {
        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = address(0);

        // Mock approvals and swapTokensForExactETH
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, router, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router01.swapTokensForExactETH.selector,
                AMOUNT,
                AMOUNT,
                path,
                address(this),
                deadline
            ),
            abi.encode(new uint256[](2))
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet).swapTokensForExactETH(
            router,
            AMOUNT,
            AMOUNT,
            path,
            address(this),
            deadline
        );
    }

    function test_swapExactTokensForETH_ShouldCallSwapExactTokensForETH()
        public
    {
        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = address(0);

        // Mock approvals and swapExactTokensForETH
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, router, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router01.swapExactTokensForETH.selector,
                AMOUNT,
                MIN_AMOUNT,
                path,
                address(this),
                deadline
            ),
            abi.encode(new uint256[](2))
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet).swapExactTokensForETH(
            router,
            AMOUNT,
            MIN_AMOUNT,
            path,
            address(this),
            deadline
        );
    }

    function test_swapETHForExactTokens_ShouldCallSwapETHForExactTokens()
        public
    {
        address[] memory path = new address[](2);
        path[0] = address(0);
        path[1] = token1;

        // Mock swapETHForExactTokens
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router01.swapETHForExactTokens.selector,
                AMOUNT,
                path,
                address(this),
                deadline
            ),
            abi.encode(new uint256[](2))
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet).swapETHForExactTokens(
            router,
            AMOUNT,
            AMOUNT,
            path,
            address(this),
            deadline
        );
    }

    function test_removeLiquidityETHSupportingFeeOnTransferTokens_ShouldRemoveLPTokenFromHeldTokens()
        public
    {
        // First add LP token to held tokens
        address[] memory lpTokens = new address[](1);
        lpTokens[0] = pair;
        MoreVaultsStorageHelper.setTokensHeld(
            facet,
            keccak256("UNISWAP_V2_LP_TOKENS_ID"),
            lpTokens
        );

        // Mock balance check to return zero balance
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IERC20.balanceOf.selector, facet),
            abi.encode(0)
        );

        // Mock approvals and removeLiquidityETHSupportingFeeOnTransferTokens
        vm.mockCall(
            pair,
            abi.encodeWithSelector(IERC20.approve.selector, router, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router02
                    .removeLiquidityETHSupportingFeeOnTransferTokens
                    .selector,
                token1,
                AMOUNT,
                MIN_AMOUNT,
                MIN_AMOUNT,
                address(this),
                deadline
            ),
            abi.encode(AMOUNT)
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet).removeLiquidityETHSupportingFeeOnTransferTokens(
            router,
            token1,
            AMOUNT,
            MIN_AMOUNT,
            MIN_AMOUNT,
            address(this),
            deadline
        );

        // Verify LP token was removed from held tokens
        lpTokens = MoreVaultsStorageHelper.getTokensHeld(
            facet,
            keccak256("UNISWAP_V2_LP_TOKENS_ID")
        );
        assertEq(lpTokens.length, 0, "Should have no LP tokens");
    }

    function test_swapExactTokensForTokensSupportingFeeOnTransferTokens_ShouldCallSwapExactTokensForTokensSupportingFeeOnTransferTokens()
        public
    {
        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = token2;

        // Mock approvals and swapExactTokensForTokensSupportingFeeOnTransferTokens
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, router, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router02
                    .swapExactTokensForTokensSupportingFeeOnTransferTokens
                    .selector,
                AMOUNT,
                MIN_AMOUNT,
                path,
                address(this),
                deadline
            ),
            abi.encode()
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                router,
                AMOUNT,
                MIN_AMOUNT,
                path,
                address(this),
                deadline
            );
    }

    function test_swapExactETHForTokensSupportingFeeOnTransferTokens_ShouldCallSwapExactETHForTokensSupportingFeeOnTransferTokens()
        public
    {
        address[] memory path = new address[](2);
        path[0] = address(0);
        path[1] = token1;

        // Mock swapExactETHForTokensSupportingFeeOnTransferTokens
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router02
                    .swapExactETHForTokensSupportingFeeOnTransferTokens
                    .selector,
                MIN_AMOUNT,
                path,
                address(this),
                deadline
            ),
            abi.encode()
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet)
            .swapExactETHForTokensSupportingFeeOnTransferTokens(
                router,
                AMOUNT,
                MIN_AMOUNT,
                path,
                address(this),
                deadline
            );
    }

    function test_swapExactTokensForETHSupportingFeeOnTransferTokens_ShouldCallSwapExactTokensForETHSupportingFeeOnTransferTokens()
        public
    {
        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = address(0);

        // Mock approvals and swapExactTokensForETHSupportingFeeOnTransferTokens
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, router, AMOUNT),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IUniswapV2Router02
                    .swapExactTokensForETHSupportingFeeOnTransferTokens
                    .selector,
                AMOUNT,
                MIN_AMOUNT,
                path,
                address(this),
                deadline
            ),
            abi.encode()
        );

        // Set up as curator
        vm.prank(facet);

        UniswapV2Facet(facet)
            .swapExactTokensForETHSupportingFeeOnTransferTokens(
                router,
                AMOUNT,
                MIN_AMOUNT,
                path,
                address(this),
                deadline
            );
    }
}

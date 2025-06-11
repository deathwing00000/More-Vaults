// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {BaseFacetInitializer, ICurveFacet, CurveFacet, ICurveRouter, ICurveViews, IERC20} from "../../../src/facets/CurveFacet.sol";
import {AccessControlLib} from "../../../src/libraries/AccessControlLib.sol";
import {MoreVaultsStorageHelper} from "../../helper/MoreVaultsStorageHelper.sol";
import {MoreVaultsLib} from "../../../src/libraries/MoreVaultsLib.sol";
import {IMoreVaultsRegistry} from "../../../src/interfaces/IMoreVaultsRegistry.sol";

contract CurveFacetTest is Test {
    CurveFacet public facet;

    address public zeroAddress = address(0);
    address public curator = address(1);
    address public unauthorized = address(2);
    address public router = address(3);
    address public token1 = address(4);
    address public token2 = address(5);
    address public recipient = address(6);
    address public pool = address(7);
    address public registry = address(8);

    address[11] public route;
    uint256[5][5] public swap_params;
    uint256[4][5] public swap_params_ng;

    // Storage slot for AccessControlStorage struct
    bytes32 constant ACCESS_CONTROL_STORAGE_POSITION =
        AccessControlLib.ACCESS_CONTROL_STORAGE_POSITION;

    function setUp() public {
        // Deploy facet
        facet = new CurveFacet();

        // Set curator role
        vm.store(
            address(facet),
            bytes32(uint256(ACCESS_CONTROL_STORAGE_POSITION) + 0),
            bytes32(uint256(uint160(curator)))
        );

        // Set initial values using helper library
        address[] memory assets = new address[](2);
        assets[0] = token1;
        assets[1] = token2;
        MoreVaultsStorageHelper.setAvailableAssets(address(facet), assets);
        MoreVaultsStorageHelper.setMoreVaultsRegistry(address(facet), registry);

        // Mock token approvals
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

        route[0] = token1;
        route[1] = pool;
        route[2] = token2;

        swap_params[0][0] = 0; // index of the first token in the pool
        swap_params[0][1] = 1; // index of the second token in the pool
        swap_params[0][2] = 1; // default swap
        swap_params[0][3] = 1; // stable pool
        swap_params[0][4] = 2; // two coins in the pool

        swap_params_ng[0][0] = 0; // index of the first token in the pool
        swap_params_ng[0][1] = 1; // index of the second token in the pool
        swap_params_ng[0][2] = 1; // default swap
        swap_params_ng[0][3] = 1; // stable pool

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                router
            ),
            abi.encode(true)
        );
    }

    function test_facetName_ShouldReturnCorrectName() public view {
        assertEq(
            facet.facetName(),
            "CurveFacet",
            "Facet name should be correct"
        );
    }

    function test_initialize_ShouldSetParametersCorrectly() public {
        bytes32 facetSelector = keccak256(abi.encodePacked("accountingCurveFacet()"));
        assembly { 
            facetSelector := shl(224, facetSelector)
        }
        CurveFacet(facet).initialize(abi.encode(facet,facetSelector));
        bytes32[] memory facets = MoreVaultsStorageHelper
            .getFacetsForAccounting(address(facet));
        assertEq(
            facets.length,
            1,
            "Facets for accounting length should be equal to 1"
        );
        assertEq(
            facets[0],
            facetSelector,
            "Facet stored should be equal to facet address"
        );
        assertEq(
            MoreVaultsStorageHelper.getSupportedInterface(
                address(facet),
                type(ICurveFacet).interfaceId
            ),
            true,
            "Supported interfaces should be set"
        );
    }

    function test_exchangeNg_ShouldPerformExchange() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;

        IERC20(token1).approve(address(facet), amount);

        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, router, amount),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "exchange(address[11],uint256[4][5],uint256,uint256,address)"
                    )
                ),
                route,
                swap_params_ng,
                amount,
                minAmount,
                address(facet)
            ),
            abi.encode(amount)
        );

        uint256 received = facet.exchangeNg(
            router,
            route,
            swap_params_ng,
            amount,
            minAmount
        );

        assertEq(received, amount);

        vm.stopPrank();
    }

    function test_exchangeNg_ShouldRevertIfOutputTokenNotAvailable() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;
        address unsupportedToken = address(123456);
        route[2] = unsupportedToken;

        IERC20(token1).approve(address(facet), amount);

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                unsupportedToken
            )
        );
        facet.exchangeNg(router, route, swap_params_ng, amount, minAmount);

        vm.stopPrank();
    }

    function test_exchangeNg_ShouldRevertIfInputTokenNotAvailable() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;
        address unsupportedToken = address(123456);
        route[0] = unsupportedToken;

        IERC20(token1).approve(address(facet), amount);

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                unsupportedToken
            )
        );
        facet.exchangeNg(router, route, swap_params_ng, amount, minAmount);

        vm.stopPrank();
    }

    function test_exchangeNg_ShouldRevertIfRouterIsNotWhitelisted() public {
        vm.startPrank(address(facet));

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                router
            ),
            abi.encode(false)
        );

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                router
            )
        );
        facet.exchangeNg(router, route, swap_params_ng, amount, minAmount);

        vm.stopPrank();
    }

    function test_exchangeNg_ShouldRevertIfAddingLiquidityAndInThatPoolFirstCoinNotAvaialable()
        public
    {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;
        address unsupportedToken = address(123456);
        route[2] = pool;
        swap_params_ng[0][2] = 4;

        IERC20(token1).approve(address(facet), amount);

        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, router, amount),
            abi.encode(true)
        );
        vm.mockCall(
            pool,
            abi.encodeWithSelector(ICurveViews.coins.selector, 0),
            abi.encode(unsupportedToken)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                unsupportedToken
            )
        );
        facet.exchangeNg(router, route, swap_params_ng, amount, minAmount);

        vm.stopPrank();
    }

    function test_exchangeNg_ShouldRevertIfSwapTypeIsNotValid() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;
        swap_params_ng[0][2] = 5;

        IERC20(token1).approve(address(facet), amount);

        vm.expectRevert(
            abi.encodeWithSelector(ICurveFacet.InvalidSwapType.selector, 0)
        );
        facet.exchangeNg(router, route, swap_params_ng, amount, minAmount);

        vm.stopPrank();
    }

    function test_exchangeNg_ShouldAddTokenToArrayIfLiquidityAdded() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;

        route[2] = pool;
        swap_params_ng[0][2] = 4; // add liquidity

        IERC20(token1).approve(address(facet), amount);

        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, router, amount),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "exchange(address[11],uint256[4][5],uint256,uint256,address)"
                    )
                ),
                route,
                swap_params_ng,
                amount,
                minAmount,
                address(facet)
            ),
            abi.encode(amount)
        );
        vm.mockCall(
            pool,
            abi.encodeWithSelector(ICurveViews.coins.selector, 0),
            abi.encode(token1)
        );

        uint256 received = facet.exchangeNg(
            router,
            route,
            swap_params_ng,
            amount,
            minAmount
        );

        // Verify LP token was added to held tokens
        address[] memory lpTokens = MoreVaultsStorageHelper.getTokensHeld(
            address(facet),
            keccak256("CURVE_LP_TOKENS_ID")
        );
        assertEq(received, amount);
        assertEq(lpTokens.length, 1, "Should have one LP token");
        assertEq(lpTokens[0], pool, "Should have correct LP token");

        vm.stopPrank();
    }

    function test_exchangeNg_ShouldRemoveTokenFromArrayOnLiquidityRemoval()
        public
    {
        address[] memory lpToken = new address[](1);
        lpToken[0] = pool;
        MoreVaultsStorageHelper.setTokensHeld(
            address(facet),
            keccak256("CURVE_LP_TOKENS_ID"),
            lpToken
        );

        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;

        route[0] = pool;
        swap_params_ng[0][2] = 6; // add liquidity

        IERC20(token1).approve(address(facet), amount);

        vm.mockCall(
            pool,
            abi.encodeWithSelector(IERC20.approve.selector, router, amount),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "exchange(address[11],uint256[4][5],uint256,uint256,address)"
                    )
                ),
                route,
                swap_params_ng,
                amount,
                minAmount,
                address(facet)
            ),
            abi.encode(amount)
        );

        vm.mockCall(
            pool,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(facet)),
            abi.encode(0)
        );

        uint256 received = facet.exchangeNg(
            router,
            route,
            swap_params_ng,
            amount,
            minAmount
        );

        // Verify LP token was added to held tokens
        address[] memory lpTokens = MoreVaultsStorageHelper.getTokensHeld(
            address(facet),
            keccak256("CURVE_LP_TOKENS_ID")
        );
        assertEq(received, amount);
        assertEq(lpTokens.length, 0, "Should have zero LP token");

        vm.stopPrank();
    }

    function test_exchange_ShouldPerformExchange() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;

        address[5] memory pools; // Array of pools for swaps via zap contracts. This parameter is only needed for swap_type = 3.

        IERC20(token1).approve(address(facet), amount);

        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, router, amount),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "exchange(address[11],uint256[5][5],uint256,uint256,address[5],address)"
                    )
                ),
                route,
                swap_params,
                amount,
                minAmount,
                pools,
                address(facet)
            ),
            abi.encode(amount)
        );

        uint256 received = facet.exchange(
            router,
            route,
            swap_params,
            amount,
            minAmount,
            pools
        );

        assertEq(received, amount);

        vm.stopPrank();
    }

    function test_exchange_ShouldRevertIfOutputTokenNotAvailable() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;
        address unsupportedToken = address(123456);
        route[2] = unsupportedToken;

        address[5] memory pools; // Array of pools for swaps via zap contracts. This parameter is only needed for swap_type = 3.

        IERC20(token1).approve(address(facet), amount);

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                unsupportedToken
            )
        );
        facet.exchange(router, route, swap_params, amount, minAmount, pools);

        vm.stopPrank();
    }

    function test_exchange_ShouldRevertIfInputTokenNotAvailable() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;
        address unsupportedToken = address(123456);
        route[0] = unsupportedToken;

        address[5] memory pools; // Array of pools for swaps via zap contracts. This parameter is only needed for swap_type = 3.

        IERC20(token1).approve(address(facet), amount);

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                unsupportedToken
            )
        );
        facet.exchange(router, route, swap_params, amount, minAmount, pools);

        vm.stopPrank();
    }

    function test_exchange_ShouldRevertIfRouterIsNotWhitelisted() public {
        vm.startPrank(address(facet));

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                router
            ),
            abi.encode(false)
        );

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;
        address[5] memory pools; // Array of pools for swaps via zap contracts. This parameter is only needed for swap_type = 3.

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                router
            )
        );
        facet.exchange(router, route, swap_params, amount, minAmount, pools);

        vm.stopPrank();
    }

    function test_exchange_ShouldRevertIfSwapTypeIsNotValid() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;
        swap_params[0][2] = 5;

        address[5] memory pools; // Array of pools for swaps via zap contracts. This parameter is only needed for swap_type = 3.

        IERC20(token1).approve(address(facet), amount);

        vm.expectRevert(
            abi.encodeWithSelector(ICurveFacet.InvalidSwapType.selector, 0)
        );
        facet.exchange(router, route, swap_params, amount, minAmount, pools);

        vm.stopPrank();
    }

    function test_exchange_ShouldRevertIfAddingLiquidityAndInThatPoolFirstCoinNotAvaialable()
        public
    {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;
        address unsupportedToken = address(123456);
        route[2] = pool;
        swap_params[0][2] = 4;

        address[5] memory pools; // Array of pools for swaps via zap contracts. This parameter is only needed for swap_type = 3.

        IERC20(token1).approve(address(facet), amount);

        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, router, amount),
            abi.encode(true)
        );
        vm.mockCall(
            pool,
            abi.encodeWithSelector(ICurveViews.coins.selector, 0),
            abi.encode(unsupportedToken)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                unsupportedToken
            )
        );
        facet.exchange(router, route, swap_params, amount, minAmount, pools);

        vm.stopPrank();
    }

    function test_exchange_ShouldAddTokenToArrayIfLiquidityAdded() public {
        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;

        route[2] = pool;
        swap_params[0][2] = 4; // add liquidity

        address[5] memory pools; // Array of pools for swaps via zap contracts. This parameter is only needed for swap_type = 3.

        IERC20(token1).approve(address(facet), amount);

        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector, router, amount),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "exchange(address[11],uint256[5][5],uint256,uint256,address[5],address)"
                    )
                ),
                route,
                swap_params,
                amount,
                minAmount,
                pools,
                address(facet)
            ),
            abi.encode(amount)
        );
        vm.mockCall(
            pool,
            abi.encodeWithSelector(ICurveViews.coins.selector, 0),
            abi.encode(token1)
        );

        uint256 received = facet.exchange(
            router,
            route,
            swap_params,
            amount,
            minAmount,
            pools
        );

        // Verify LP token was added to held tokens
        address[] memory lpTokens = MoreVaultsStorageHelper.getTokensHeld(
            address(facet),
            keccak256("CURVE_LP_TOKENS_ID")
        );
        assertEq(received, amount);
        assertEq(lpTokens.length, 1, "Should have one LP token");
        assertEq(lpTokens[0], pool, "Should have correct LP token");

        vm.stopPrank();
    }

    function test_exchange_ShouldRemoveTokenFromArrayOnLiquidityRemoval()
        public
    {
        address[] memory lpToken = new address[](1);
        lpToken[0] = pool;
        MoreVaultsStorageHelper.setTokensHeld(
            address(facet),
            keccak256("CURVE_LP_TOKENS_ID"),
            lpToken
        );

        address[5] memory pools; // Array of pools for swaps via zap contracts. This parameter is only needed for swap_type = 3.

        vm.startPrank(address(facet));

        uint256 amount = 1e18;
        uint256 minAmount = 0.9e18;

        route[0] = pool;
        swap_params[0][2] = 6; // add liquidity

        IERC20(token1).approve(address(facet), amount);

        vm.mockCall(
            pool,
            abi.encodeWithSelector(IERC20.approve.selector, router, amount),
            abi.encode(true)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "exchange(address[11],uint256[5][5],uint256,uint256,address[5],address)"
                    )
                ),
                route,
                swap_params,
                amount,
                minAmount,
                pools,
                address(facet)
            ),
            abi.encode(amount)
        );

        vm.mockCall(
            pool,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(facet)),
            abi.encode(0)
        );

        uint256 received = facet.exchange(
            router,
            route,
            swap_params,
            amount,
            minAmount,
            pools
        );

        // Verify LP token was added to held tokens
        address[] memory lpTokens = MoreVaultsStorageHelper.getTokensHeld(
            address(facet),
            keccak256("CURVE_LP_TOKENS_ID")
        );
        assertEq(received, amount);
        assertEq(lpTokens.length, 0, "Should have zero LP token");

        vm.stopPrank();
    }
}

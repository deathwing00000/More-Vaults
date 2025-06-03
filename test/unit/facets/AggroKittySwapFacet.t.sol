// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AggroKittySwapFacet} from "../../../src/facets/AggroKittySwapFacet.sol";
import {IAggroKittySwapFacet} from "../../../src/interfaces/facets/IAggroKittySwapFacet.sol";
import {IAggroKittyRouter} from "../../../src/interfaces/KittyPunch/IAggroKittyRouter.sol";
import {MoreVaultsStorageHelper} from "../../helper/MoreVaultsStorageHelper.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AccessControlLib} from "../../../src/libraries/AccessControlLib.sol";
import {MoreVaultsLib} from "../../../src/libraries/MoreVaultsLib.sol";
import {BaseFacetInitializer} from "../../../src/facets/BaseFacetInitializer.sol";
import {IMoreVaultsRegistry} from "../../../src/interfaces/IMoreVaultsRegistry.sol";
import {MoreVaultsLib} from "../../../src/libraries/MoreVaultsLib.sol";

contract AggroKittySwapFacetTest is Test {
    // Test addresses
    address public facet = address(100);
    address public router = address(4);
    address public curator = address(7);
    address public user = address(8);
    address public token1 = address(2);
    address public token2 = address(3);
    address public wrappedNative = address(4);
    address public recipient = address(9);
    address public registry = address(10);

    // Test amounts
    uint256 constant AMOUNT = 1e18;
    uint256 constant MIN_AMOUNT = 1e17;
    uint256 public deadline;

    // Storage slot for AccessControlStorage struct
    bytes32 constant ACCESS_CONTROL_STORAGE_POSITION =
        AccessControlLib.ACCESS_CONTROL_STORAGE_POSITION;

    function setUp() public {
        deadline = block.timestamp + 1 hours;

        // Deploy facet
        AggroKittySwapFacet facetContract = new AggroKittySwapFacet();
        facet = address(facetContract);

        // Set initial values in storage
        address[] memory availableAssets = new address[](3);
        availableAssets[0] = token1;
        availableAssets[1] = token2;
        availableAssets[2] = wrappedNative;
        MoreVaultsStorageHelper.setWrappedNative(facet, wrappedNative);
        MoreVaultsStorageHelper.setAvailableAssets(facet, availableAssets);
        MoreVaultsStorageHelper.setCurator(facet, curator);
        MoreVaultsStorageHelper.setMoreVaultsRegistry(facet, registry);

        // Mock token approvals
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

        // Mock router calls
        vm.mockCall(
            router,
            abi.encodeWithSelector(IAggroKittyRouter.swapNoSplit.selector),
            abi.encode(MIN_AMOUNT)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IAggroKittyRouter.swapNoSplitFromNative.selector
            ),
            abi.encode(MIN_AMOUNT)
        );
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IAggroKittyRouter.swapNoSplitToNative.selector
            ),
            abi.encode(MIN_AMOUNT)
        );

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                router
            ),
            abi.encode(true)
        );
        vm.deal(facet, 100000 ether);
    }

    function test_facetName_ShouldReturnCorrectName() public view {
        assertEq(
            AggroKittySwapFacet(facet).facetName(),
            "AggroKittySwapFacet",
            "Facet name should be correct"
        );
    }

    function test_initialize_ShouldSetFacetAddress() public {
        AggroKittySwapFacet(facet).initialize(abi.encode(facet));
        MoreVaultsStorageHelper.getStorageValue(facet, 0); // Verify storage was updated
    }

    function test_initialize_ShouldRevertWhenAlreadyInitialized() public {
        // First initialization
        AggroKittySwapFacet(facet).initialize(abi.encode(facet));

        // Try to initialize again
        vm.expectRevert(BaseFacetInitializer.AlreadyInitialized.selector);
        AggroKittySwapFacet(facet).initialize(abi.encode(facet));
    }

    function test_allNonViewFunctions_ShouldRevertWhenCalledByNonDiamond()
        public
    {
        vm.startPrank(user);

        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = token2;
        IAggroKittyRouter.Trade memory trade = IAggroKittyRouter.Trade({
            amountIn: AMOUNT,
            amountOut: MIN_AMOUNT,
            path: path,
            adapters: new address[](0)
        });

        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AggroKittySwapFacet(facet).swapNoSplit(router, trade);

        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AggroKittySwapFacet(facet).swapNoSplitFromNative(router, trade);

        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AggroKittySwapFacet(facet).swapNoSplitToNative(router, trade);

        vm.stopPrank();
    }

    function test_allNonViewFunctions_ShouldRevertWhenCalledToNonWhitelistedRouter()
        public
    {
        vm.startPrank(facet);

        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = token2;
        IAggroKittyRouter.Trade memory trade = IAggroKittyRouter.Trade({
            amountIn: AMOUNT,
            amountOut: MIN_AMOUNT,
            path: path,
            adapters: new address[](0)
        });

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isWhitelisted.selector,
                router
            ),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                router
            )
        );
        AggroKittySwapFacet(facet).swapNoSplit(router, trade);

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                router
            )
        );
        AggroKittySwapFacet(facet).swapNoSplitFromNative(router, trade);

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                router
            )
        );
        AggroKittySwapFacet(facet).swapNoSplitToNative(router, trade);

        vm.stopPrank();
    }

    function test_swapNoSplit_ShouldPerformSwap() public {
        vm.startPrank(facet);

        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = token2;
        IAggroKittyRouter.Trade memory trade = IAggroKittyRouter.Trade({
            amountIn: AMOUNT,
            amountOut: MIN_AMOUNT,
            path: path,
            adapters: new address[](0)
        });

        AggroKittySwapFacet(facet).swapNoSplit(router, trade);

        vm.stopPrank();
    }

    function test_swapNoSplit_ShouldRevertWhenInvalidInputToken() public {
        vm.startPrank(facet);

        address unsupportedToken = address(5);
        address[] memory path = new address[](2);
        path[0] = unsupportedToken;
        path[1] = token2;
        IAggroKittyRouter.Trade memory trade = IAggroKittyRouter.Trade({
            amountIn: AMOUNT,
            amountOut: MIN_AMOUNT,
            path: path,
            adapters: new address[](0)
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                unsupportedToken
            )
        );
        AggroKittySwapFacet(facet).swapNoSplit(router, trade);

        vm.stopPrank();
    }

    function test_swapNoSplit_ShouldRevertWhenInvalidOutputToken() public {
        vm.startPrank(facet);

        address unsupportedToken = address(5);
        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = unsupportedToken;
        IAggroKittyRouter.Trade memory trade = IAggroKittyRouter.Trade({
            amountIn: AMOUNT,
            amountOut: MIN_AMOUNT,
            path: path,
            adapters: new address[](0)
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                unsupportedToken
            )
        );
        AggroKittySwapFacet(facet).swapNoSplit(router, trade);

        vm.stopPrank();
    }

    function test_swapNoSplitFromNative_ShouldPerformSwap() public {
        vm.startPrank(facet);

        address[] memory path = new address[](2);
        path[0] = address(0);
        path[1] = token1;
        IAggroKittyRouter.Trade memory trade = IAggroKittyRouter.Trade({
            amountIn: AMOUNT,
            amountOut: MIN_AMOUNT,
            path: path,
            adapters: new address[](0)
        });

        vm.deal(facet, AMOUNT);
        AggroKittySwapFacet(facet).swapNoSplitFromNative(router, trade);

        vm.stopPrank();
    }

    function test_swapNoSplitToNative_ShouldPerformSwap() public {
        vm.startPrank(facet);

        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = address(0);
        IAggroKittyRouter.Trade memory trade = IAggroKittyRouter.Trade({
            amountIn: AMOUNT,
            amountOut: MIN_AMOUNT,
            path: path,
            adapters: new address[](0)
        });

        AggroKittySwapFacet(facet).swapNoSplitToNative(router, trade);

        vm.stopPrank();
    }
}

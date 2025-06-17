// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IUniswapV3Facet, UniswapV3Facet} from "../../../src/facets/UniswapV3Facet.sol";
import {AccessControlLib} from "../../../src/libraries/AccessControlLib.sol";
import {MoreVaultsStorageHelper} from "../../helper/MoreVaultsStorageHelper.sol";
import {ISwapRouter} from "../../../src/interfaces/Uniswap/v3/ISwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MoreVaultsLib} from "../../../src/libraries/MoreVaultsLib.sol";
import {IMoreVaultsRegistry} from "../../../src/interfaces/IMoreVaultsRegistry.sol";

contract UniswapV3FacetTest is Test {
    UniswapV3Facet public facet;

    address public curator = address(1);
    address public unauthorized = address(2);
    address public router = address(3);
    address public token1 = address(4);
    address public token2 = address(5);
    address public zeroAddress = address(0);
    address public recipient = address(6);
    address public registry = address(7);

    // Storage slot for AccessControlStorage struct
    bytes32 constant ACCESS_CONTROL_STORAGE_POSITION =
        AccessControlLib.ACCESS_CONTROL_STORAGE_POSITION;

    // Mock data
    bytes public path;
    uint256 public amountIn = 1000;
    uint256 public amountInMax = 2000;
    uint256 public amountOut = 500;
    uint256 public amountOutMin = 400;
    uint256 public deadline;
    uint24 public fee = 100;
    uint160 public sqrtPriceLimitX96 = 0;

    function setUp() public {
        // Deploy facet
        facet = new UniswapV3Facet();

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

        // Setup path for swaps
        path = abi.encodePacked(token1, fee, token2);

        // Set deadline
        deadline = block.timestamp + 1 hours;

        // Mock token approvals
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

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
            "UniswapV3Facet",
            "Facet name should be correct"
        );
    }

    function test_initialize_ShouldSetSupportedInterfaces() public {
        UniswapV3Facet(facet).initialize("");
        assertEq(
            MoreVaultsStorageHelper.getSupportedInterface(
                address(facet),
                type(IUniswapV3Facet).interfaceId
            ),
            true,
            "Supported interfaces should be set"
        );
    }

    function test_allNonViewFunctions_ShouldRevertWhenCalledByNonDiamond()
        public
    {
        vm.startPrank(unauthorized);

        ISwapRouter.ExactInputSingleParams
            memory exactInputSingleParams = ISwapRouter.ExactInputSingleParams({
                tokenIn: token1,
                tokenOut: token2,
                fee: fee,
                recipient: recipient,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: sqrtPriceLimitX96
            });

        ISwapRouter.ExactInputParams memory exactInputParams = ISwapRouter
            .ExactInputParams({
                path: path,
                recipient: recipient,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin
            });

        ISwapRouter.ExactOutputSingleParams
            memory exactOutputSingleParams = ISwapRouter
                .ExactOutputSingleParams({
                    tokenIn: token1,
                    tokenOut: token2,
                    fee: fee,
                    recipient: recipient,
                    deadline: deadline,
                    amountOut: amountOut,
                    amountInMaximum: amountInMax,
                    sqrtPriceLimitX96: sqrtPriceLimitX96
                });

        ISwapRouter.ExactOutputParams memory exactOutputParams = ISwapRouter
            .ExactOutputParams({
                path: path,
                recipient: recipient,
                deadline: deadline,
                amountOut: amountOut,
                amountInMaximum: amountInMax
            });

        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        UniswapV3Facet(facet).exactInputSingle(router, exactInputSingleParams);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        UniswapV3Facet(facet).exactInput(router, exactInputParams);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        UniswapV3Facet(facet).exactOutputSingle(
            router,
            exactOutputSingleParams
        );
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        UniswapV3Facet(facet).exactOutput(router, exactOutputParams);

        vm.stopPrank();
    }

    function test_allNonViewFunctions_ShouldRevertWhenCalledByNonWhitelistedRouter()
        public
    {
        vm.startPrank(address(facet));

        ISwapRouter.ExactInputSingleParams
            memory exactInputSingleParams = ISwapRouter.ExactInputSingleParams({
                tokenIn: token1,
                tokenOut: token2,
                fee: fee,
                recipient: recipient,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: sqrtPriceLimitX96
            });

        ISwapRouter.ExactInputParams memory exactInputParams = ISwapRouter
            .ExactInputParams({
                path: path,
                recipient: recipient,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin
            });

        ISwapRouter.ExactOutputSingleParams
            memory exactOutputSingleParams = ISwapRouter
                .ExactOutputSingleParams({
                    tokenIn: token1,
                    tokenOut: token2,
                    fee: fee,
                    recipient: recipient,
                    deadline: deadline,
                    amountOut: amountOut,
                    amountInMaximum: amountInMax,
                    sqrtPriceLimitX96: sqrtPriceLimitX96
                });

        ISwapRouter.ExactOutputParams memory exactOutputParams = ISwapRouter
            .ExactOutputParams({
                path: path,
                recipient: recipient,
                deadline: deadline,
                amountOut: amountOut,
                amountInMaximum: amountInMax
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
        UniswapV3Facet(facet).exactInputSingle(router, exactInputSingleParams);
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                router
            )
        );
        UniswapV3Facet(facet).exactInput(router, exactInputParams);
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                router
            )
        );
        UniswapV3Facet(facet).exactOutputSingle(
            router,
            exactOutputSingleParams
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedProtocol.selector,
                router
            )
        );
        UniswapV3Facet(facet).exactOutput(router, exactOutputParams);

        vm.stopPrank();
    }

    function test_exactOutputSingle_ShouldPerformSwap() public {
        vm.startPrank(address(facet));

        // Prepare swap parameters
        ISwapRouter.ExactOutputSingleParams
            memory exactOutputSingleParams = ISwapRouter
                .ExactOutputSingleParams({
                    tokenIn: token1,
                    tokenOut: token2,
                    fee: fee,
                    recipient: recipient,
                    deadline: deadline,
                    amountOut: amountOut,
                    amountInMaximum: amountInMax,
                    sqrtPriceLimitX96: sqrtPriceLimitX96
                });

        // Mock swap contract calls
        vm.mockCall(
            router,
            abi.encodeWithSelector(ISwapRouter.exactOutputSingle.selector),
            abi.encode(amountOutMin)
        );

        // Perform swap
        uint256 amountOutReturned = UniswapV3Facet(facet).exactOutputSingle(
            router,
            exactOutputSingleParams
        );

        // Verify results
        assertEq(amountOutReturned, amountOutMin);

        vm.stopPrank();
    }

    function test_exactOutputSingle_ShouldRevertWhenInvalidInputToken() public {
        vm.startPrank(address(facet));

        // Prepare swap parameters
        ISwapRouter.ExactOutputSingleParams
            memory exactOutputSingleParams = ISwapRouter
                .ExactOutputSingleParams({
                    tokenIn: address(0),
                    tokenOut: token2,
                    fee: fee,
                    recipient: recipient,
                    deadline: deadline,
                    amountOut: amountOut,
                    amountInMaximum: amountInMax,
                    sqrtPriceLimitX96: sqrtPriceLimitX96
                });

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                zeroAddress
            )
        );
        UniswapV3Facet(facet).exactOutputSingle(
            router,
            exactOutputSingleParams
        );

        vm.stopPrank();
    }

    function test_exactOutputSingle_ShouldRevertWhenInvalidOutputToken()
        public
    {
        vm.startPrank(address(facet));

        // Prepare swap parameters
        ISwapRouter.ExactOutputSingleParams
            memory exactOutputSingleParams = ISwapRouter
                .ExactOutputSingleParams({
                    tokenIn: token1,
                    tokenOut: address(0),
                    fee: fee,
                    recipient: recipient,
                    deadline: deadline,
                    amountOut: amountOut,
                    amountInMaximum: amountInMax,
                    sqrtPriceLimitX96: sqrtPriceLimitX96
                });

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                zeroAddress
            )
        );
        UniswapV3Facet(facet).exactOutputSingle(
            router,
            exactOutputSingleParams
        );

        vm.stopPrank();
    }

    function test_exactOutput_ShouldPerformSwap() public {
        vm.startPrank(address(facet));

        path = abi.encodePacked(token2, fee, token1);
        // Prepare swap parameters
        ISwapRouter.ExactOutputParams memory exactOutputParams = ISwapRouter
            .ExactOutputParams({
                path: path,
                recipient: recipient,
                deadline: deadline,
                amountOut: amountOut,
                amountInMaximum: amountInMax
            });

        // Mock swap contract calls
        vm.mockCall(
            router,
            abi.encodeWithSelector(ISwapRouter.exactOutput.selector),
            abi.encode(amountOutMin)
        );

        // Perform swap
        uint256 amountOutReturned = UniswapV3Facet(facet).exactOutput(
            router,
            exactOutputParams
        );

        // Verify results
        assertEq(amountOutReturned, amountOutMin);

        vm.stopPrank();
    }

    function test_exactOutput_ShouldRevertWhenInvalidInputToken() public {
        vm.startPrank(address(facet));

        bytes memory invalidPath = abi.encodePacked(zeroAddress, fee, token2);

        // Prepare swap parameters
        ISwapRouter.ExactOutputParams memory exactOutputParams = ISwapRouter
            .ExactOutputParams({
                path: invalidPath,
                recipient: recipient,
                deadline: deadline,
                amountOut: amountOut,
                amountInMaximum: amountInMax
            });

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                zeroAddress
            )
        );
        UniswapV3Facet(facet).exactOutput(router, exactOutputParams);

        vm.stopPrank();
    }

    function test_exactOutput_ShouldRevertWhenInvalidOutputToken() public {
        vm.startPrank(address(facet));

        bytes memory invalidPath = abi.encodePacked(zeroAddress, fee, token2);

        // Prepare swap parameters
        ISwapRouter.ExactOutputParams memory exactOutputParams = ISwapRouter
            .ExactOutputParams({
                path: invalidPath,
                recipient: recipient,
                deadline: deadline,
                amountOut: amountOut,
                amountInMaximum: amountInMax
            });

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                zeroAddress
            )
        );
        UniswapV3Facet(facet).exactOutput(router, exactOutputParams);

        vm.stopPrank();
    }

    function test_exactInputSingle_ShouldPerformSwap() public {
        vm.startPrank(address(facet));

        // Prepare swap parameters
        ISwapRouter.ExactInputSingleParams
            memory exactInputSingleParams = ISwapRouter.ExactInputSingleParams({
                tokenIn: token1,
                tokenOut: token2,
                fee: fee,
                recipient: recipient,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: sqrtPriceLimitX96
            });

        // Mock swap contract calls
        vm.mockCall(
            router,
            abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector),
            abi.encode(amountOutMin)
        );

        // Perform swap
        uint256 amountOutReturned = UniswapV3Facet(facet).exactInputSingle(
            router,
            exactInputSingleParams
        );

        // Verify results
        assertEq(amountOutReturned, amountOutMin);

        vm.stopPrank();
    }

    function test_exactInputSingle_ShouldRevertWhenInvalidInputToken() public {
        vm.startPrank(address(facet));

        // Prepare swap parameters
        ISwapRouter.ExactInputSingleParams
            memory exactInputSingleParams = ISwapRouter.ExactInputSingleParams({
                tokenIn: address(0),
                tokenOut: token2,
                fee: fee,
                recipient: recipient,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: sqrtPriceLimitX96
            });

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                zeroAddress
            )
        );
        UniswapV3Facet(facet).exactInputSingle(router, exactInputSingleParams);

        vm.stopPrank();
    }

    function test_exactInputSingle_ShouldRevertWhenInvalidOutputToken() public {
        vm.startPrank(address(facet));

        // Prepare swap parameters
        ISwapRouter.ExactInputSingleParams
            memory exactInputSingleParams = ISwapRouter.ExactInputSingleParams({
                tokenIn: token1,
                tokenOut: address(0),
                fee: fee,
                recipient: recipient,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: sqrtPriceLimitX96
            });

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                zeroAddress
            )
        );
        UniswapV3Facet(facet).exactInputSingle(router, exactInputSingleParams);

        vm.stopPrank();
    }

    function test_exactInput_ShouldPerformSwap() public {
        vm.startPrank(address(facet));

        // Prepare swap parameters
        ISwapRouter.ExactInputParams memory exactInputParams = ISwapRouter
            .ExactInputParams({
                path: path,
                recipient: recipient,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin
            });

        // Mock swap contract calls
        vm.mockCall(
            router,
            abi.encodeWithSelector(ISwapRouter.exactInput.selector),
            abi.encode(amountOutMin)
        );

        // Perform swap
        uint256 amountOutReturned = UniswapV3Facet(facet).exactInput(
            router,
            exactInputParams
        );

        // Verify results
        assertEq(amountOutReturned, amountOutMin);

        vm.stopPrank();
    }

    function test_exactInput_ShouldRevertWhenInvalidInputToken() public {
        vm.startPrank(address(facet));

        bytes memory invalidPath = abi.encodePacked(zeroAddress, fee, token2);

        // Prepare swap parameters
        ISwapRouter.ExactInputParams memory exactInputParams = ISwapRouter
            .ExactInputParams({
                path: invalidPath,
                recipient: recipient,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin
            });

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                zeroAddress
            )
        );
        UniswapV3Facet(facet).exactInput(router, exactInputParams);

        vm.stopPrank();
    }

    function test_exactInput_ShouldRevertWhenInvalidOutputToken() public {
        vm.startPrank(address(facet));

        bytes memory invalidPath = abi.encodePacked(zeroAddress, fee, token2);

        // Prepare swap parameters
        ISwapRouter.ExactInputParams memory exactInputParams = ISwapRouter
            .ExactInputParams({
                path: invalidPath,
                recipient: recipient,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin
            });

        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                zeroAddress
            )
        );
        UniswapV3Facet(facet).exactInput(router, exactInputParams);

        vm.stopPrank();
    }
}

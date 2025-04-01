// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IIzumiSwapFacet, IzumiSwapFacet} from "../../../src/facets/IzumiSwapFacet.sol";
import {AccessControlLib} from "../../../src/libraries/AccessControlLib.sol";
import {MoreVaultsStorageHelper} from "../../helper/MoreVaultsStorageHelper.sol";
import {ISwap} from "../../../src/interfaces/iZUMi/ISwap.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MoreVaultsLib} from "../../../src/libraries/MoreVaultsLib.sol";

contract IzumiSwapFacetTest is Test {
    IzumiSwapFacet public facet;

    address public curator = address(1);
    address public unauthorized = address(2);
    address public swapContract = address(3);
    address public token1 = address(4);
    address public token2 = address(5);
    address public zeroAddress = address(0);
    address public recipient = address(6);

    // Storage slot for AccessControlStorage struct
    bytes32 constant ACCESS_CONTROL_STORAGE_POSITION =
        AccessControlLib.ACCESS_CONTROL_STORAGE_POSITION;

    // Mock data
    bytes public path;
    uint256 public amount = 1000;
    uint256 public maxPayed = 2000;
    uint256 public desiredAmount = 500;
    uint256 public minAcquire = 400;
    uint256 public deadline;

    function setUp() public {
        // Deploy facet
        facet = new IzumiSwapFacet();

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

        // Setup path for swaps
        path = abi.encodePacked(token1, token2);

        // Set deadline
        deadline = block.timestamp + 1 hours;

        // Mock token approvals
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );

        // Mock swap contract calls
        vm.mockCall(
            swapContract,
            abi.encodeWithSelector(ISwap.swapAmount.selector),
            abi.encode(amount, desiredAmount)
        );
        vm.mockCall(
            swapContract,
            abi.encodeWithSelector(ISwap.swapDesire.selector),
            abi.encode(maxPayed, desiredAmount)
        );
    }

    function test_facetName_ShouldReturnCorrectName() public view {
        assertEq(
            facet.facetName(),
            "IzumiSwapFacet",
            "Facet name should be correct"
        );
    }

    function test_initialize_ShouldSetSupportedInterfaces() public {
        IzumiSwapFacet(facet).initialize("");
        assertEq(
            MoreVaultsStorageHelper.getSupportedInterface(
                address(facet),
                type(IIzumiSwapFacet).interfaceId
            ),
            true,
            "Supported interfaces should be set"
        );
    }

    function test_allNonViewFunctions_ShouldRevertWhenCalledByNonDiamond()
        public
    {
        vm.startPrank(unauthorized);

        ISwap.SwapAmountParams memory swapAmountParams = ISwap
            .SwapAmountParams({
                path: path,
                recipient: recipient,
                amount: uint128(amount),
                minAcquired: minAcquire,
                deadline: deadline
            });

        ISwap.SwapDesireParams memory swapDesireParams = ISwap
            .SwapDesireParams({
                path: path,
                recipient: recipient,
                desire: uint128(desiredAmount),
                maxPayed: maxPayed,
                deadline: deadline
            });

        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        IzumiSwapFacet(facet).swapAmount(swapContract, swapAmountParams);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        IzumiSwapFacet(facet).swapDesire(swapContract, swapDesireParams);

        vm.stopPrank();
    }

    function test_swapAmount_ShouldPerformSwap() public {
        vm.startPrank(address(facet));

        // Prepare swap parameters
        ISwap.SwapAmountParams memory params = ISwap.SwapAmountParams({
            path: path,
            recipient: recipient,
            amount: uint128(amount),
            minAcquired: minAcquire,
            deadline: deadline
        });

        // Perform swap
        (uint256 cost, uint256 acquire) = facet.swapAmount(
            swapContract,
            params
        );

        // Verify results
        assertEq(cost, amount, "Cost should match input amount");
        assertEq(acquire, desiredAmount, "Acquire should match desired amount");

        vm.stopPrank();
    }

    function test_swapAmount_ShouldRevertWhenUnauthorized() public {
        vm.startPrank(unauthorized);

        // Prepare swap parameters
        ISwap.SwapAmountParams memory params = ISwap.SwapAmountParams({
            path: path,
            recipient: recipient,
            amount: uint128(amount),
            minAcquired: minAcquire,
            deadline: deadline
        });

        // Attempt to perform swap
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        facet.swapAmount(swapContract, params);

        vm.stopPrank();
    }

    function test_swapAmount_ShouldRevertWhenInvalidInputToken() public {
        vm.startPrank(address(facet));

        // Prepare swap parameters with invalid input token
        bytes memory invalidPath = abi.encodePacked(zeroAddress, token2);
        ISwap.SwapAmountParams memory params = ISwap.SwapAmountParams({
            path: invalidPath,
            recipient: recipient,
            amount: uint128(amount),
            minAcquired: minAcquire,
            deadline: deadline
        });

        // Attempt to perform swap
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                zeroAddress
            )
        );
        facet.swapAmount(swapContract, params);

        vm.stopPrank();
    }

    function test_swapAmount_ShouldRevertWhenInvalidOutputToken() public {
        vm.startPrank(address(facet));

        // Prepare swap parameters with invalid output token
        bytes memory invalidPath = abi.encodePacked(token1, zeroAddress);
        ISwap.SwapAmountParams memory params = ISwap.SwapAmountParams({
            path: invalidPath,
            recipient: recipient,
            amount: uint128(amount),
            minAcquired: minAcquire,
            deadline: deadline
        });

        address[] memory availableAssets = MoreVaultsStorageHelper
            .getAvailableAssets(address(facet));
        for (uint256 i = 0; i < availableAssets.length; i++) {}
        // Attempt to perform swap
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                zeroAddress
            )
        );
        facet.swapAmount(swapContract, params);

        vm.stopPrank();
    }

    function test_swapDesire_ShouldPerformSwap() public {
        vm.startPrank(address(facet));

        // Prepare swap parameters
        ISwap.SwapDesireParams memory params = ISwap.SwapDesireParams({
            path: path,
            recipient: recipient,
            desire: uint128(desiredAmount),
            maxPayed: maxPayed,
            deadline: deadline
        });

        // Perform swap
        (uint256 cost, uint256 acquire) = facet.swapDesire(
            swapContract,
            params
        );

        // Verify results
        assertEq(cost, maxPayed, "Cost should match max payed amount");
        assertEq(acquire, desiredAmount, "Acquire should match desired amount");

        vm.stopPrank();
    }

    function test_swapDesire_ShouldRevertWhenUnauthorized() public {
        vm.startPrank(unauthorized);

        // Prepare swap parameters
        ISwap.SwapDesireParams memory params = ISwap.SwapDesireParams({
            path: path,
            recipient: recipient,
            desire: uint128(desiredAmount),
            maxPayed: maxPayed,
            deadline: deadline
        });

        // Attempt to perform swap
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        facet.swapDesire(swapContract, params);

        vm.stopPrank();
    }

    function test_swapDesire_ShouldRevertWhenInvalidInputToken() public {
        vm.startPrank(address(facet));

        // Prepare swap parameters with invalid input token
        bytes memory invalidPath = abi.encodePacked(zeroAddress, token2);
        ISwap.SwapDesireParams memory params = ISwap.SwapDesireParams({
            path: invalidPath,
            recipient: recipient,
            desire: uint128(desiredAmount),
            maxPayed: maxPayed,
            deadline: deadline
        });

        // Attempt to perform swap
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                zeroAddress
            )
        );
        facet.swapDesire(swapContract, params);

        vm.stopPrank();
    }

    function test_swapDesire_ShouldRevertWhenInvalidOutputToken() public {
        vm.startPrank(address(facet));

        // Prepare swap parameters with invalid output token
        bytes memory invalidPath = abi.encodePacked(token1, zeroAddress);
        ISwap.SwapDesireParams memory params = ISwap.SwapDesireParams({
            path: invalidPath,
            recipient: recipient,
            desire: uint128(desiredAmount),
            maxPayed: maxPayed,
            deadline: deadline
        });

        // Attempt to perform swap
        vm.expectRevert(
            abi.encodeWithSelector(
                MoreVaultsLib.UnsupportedAsset.selector,
                zeroAddress
            )
        );
        facet.swapDesire(swapContract, params);

        vm.stopPrank();
    }
}

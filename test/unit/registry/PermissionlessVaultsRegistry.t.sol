// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {PermissionlessVaultsRegistry} from "../../../src/registry/PermissionlessVaultsRegistry.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";

contract PermissionlessVaultsRegistryTest is Test {
    PermissionlessVaultsRegistry public registry;
    MockERC20 public usdc;
    address public admin = address(1);
    address public user = address(2);
    address public vault = address(3);
    address public recipient = address(4);
    address public oracle = address(5);

    function setUp() public {
        // Deploy mocks
        usdc = new MockERC20("USD Coin", "USDC");

        // Deploy registry
        vm.prank(admin);
        registry = new PermissionlessVaultsRegistry();
        vm.prank(admin);
        registry.initialize(address(oracle), address(usdc));

        // Mock oracle calls
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("BASE_CURRENCY()"),
            abi.encode(address(0))
        );
    }

    function test_constructor_ShouldSetInitialValues() public view {
        assertEq(
            address(registry.oracle()),
            oracle,
            "Should set correct oracle"
        );
        assertEq(
            registry.usdStableTokenAddress(),
            address(usdc),
            "Should set correct USDC address"
        );
        assertTrue(
            registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin),
            "Should set admin role"
        );
    }

    function test_isFacetAllowed_ShouldAlwaysReturnTrue() public view {
        assertTrue(
            registry.isFacetAllowed(address(0)),
            "Should allow zero address"
        );
        assertTrue(
            registry.isFacetAllowed(address(1)),
            "Should allow any address"
        );
        assertTrue(
            registry.isFacetAllowed(address(0x123)),
            "Should allow any address"
        );
    }

    function test_addFacet_ShouldRevert() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("test()"));

        vm.prank(admin);
        vm.expectRevert(
            PermissionlessVaultsRegistry.AllFacetsAllowedByDefault.selector
        );
        registry.addFacet(address(1), selectors);
    }

    function test_removeFacet_ShouldRevert() public {
        vm.prank(admin);
        vm.expectRevert(
            PermissionlessVaultsRegistry.AllFacetsAllowedByDefault.selector
        );
        registry.removeFacet(address(1));
    }

    function test_setProtocolFeeInfo_ShouldRevert() public {
        vm.prank(admin);
        vm.expectRevert(PermissionlessVaultsRegistry.FeeCannotBeSet.selector);
        registry.setProtocolFeeInfo(vault, recipient, 1000);
    }

    function test_protocolFeeInfo_ShouldAlwaysReturnZero() public view {
        (address feeRecipient, uint96 fee) = registry.protocolFeeInfo(vault);
        assertEq(feeRecipient, address(0), "Should return zero address");
        assertEq(fee, 0, "Should return zero fee");
    }

    function test_getDenominationAsset_ShouldReturnUsdc() public view {
        assertEq(
            registry.getDenominationAsset(),
            address(usdc),
            "Should return USDC address"
        );
    }

    function test_getDenominationAssetDecimals_ShouldReturnUsdcDecimals()
        public
        view
    {
        assertEq(
            registry.getDenominationAssetDecimals(),
            MockERC20(address(usdc)).decimals(),
            "Should return USDC decimals"
        );
    }

    function test_addToWhitelist_ShouldRevertForPermissionless() public {
        vm.prank(admin);
        vm.expectRevert(
            PermissionlessVaultsRegistry
                .AllProtocolsWhitelistedByDefault
                .selector
        );
        registry.addToWhitelist(vault);
    }

    function test_removeFromWhitelist_ShouldRevertForPermissionless() public {
        vm.prank(admin);
        vm.expectRevert(
            PermissionlessVaultsRegistry
                .AllProtocolsWhitelistedByDefault
                .selector
        );
        registry.removeFromWhitelist(vault);
    }

    function test_isWhitelisted_ShouldReturnTrue() public {
        assertEq(
            registry.isWhitelisted(address(1)),
            true,
            "Should be whitelisted by default"
        );
    }
}

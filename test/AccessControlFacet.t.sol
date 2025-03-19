// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IAccessControlFacet, AccessControlFacet} from "../src/facets/AccessControlFacet.sol";
import {AccessControlLib} from "../src/libraries/AccessControlLib.sol";
import {MoreVaultsLib} from "../src/libraries/MoreVaultsLib.sol";
import {IMoreVaultsRegistry} from "../src/interfaces/IMoreVaultsRegistry.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {MoreVaultsStorageHelper} from "./libraries/MoreVaultsStorageHelper.sol";

contract AccessControlFacetTest is Test {
    AccessControlFacet public facet;

    address public curator = address(1);
    address public guardian = address(2);
    address public newCurator = address(3);
    address public newGuardian = address(4);
    address public unauthorized = address(5);
    address public registry = address(6);
    address public newRegistry = address(7);
    address public facet1 = address(8);
    address public facet2 = address(9);

    // Storage slot for AccessControlStorage struct
    bytes32 constant ACCESS_CONTROL_STORAGE_POSITION =
        AccessControlLib.ACCESS_CONTROL_STORAGE_POSITION;

    function setUp() public {
        // Deploy facet
        facet = new AccessControlFacet();

        // Set initial roles using storage slots
        // AccessControlStorage struct layout:
        // - curator (address) at slot + 0
        // - guardian (address) at slot + 1
        // - moreVaultsRegistry (address) at slot + 2

        // Set curator
        vm.store(
            address(facet),
            bytes32(uint256(ACCESS_CONTROL_STORAGE_POSITION) + 0),
            bytes32(uint256(uint160(curator)))
        );

        // Set guardian
        vm.store(
            address(facet),
            bytes32(uint256(ACCESS_CONTROL_STORAGE_POSITION) + 1),
            bytes32(uint256(uint160(guardian)))
        );

        // Set registry
        vm.store(
            address(facet),
            bytes32(uint256(ACCESS_CONTROL_STORAGE_POSITION) + 2),
            bytes32(uint256(uint160(registry)))
        );

        // Setup MoreVaultsStorage using helper library
        address[] memory facets = new address[](2);
        facets[0] = facet1;
        facets[1] = facet2;
        MoreVaultsStorageHelper.setFacetAddresses(address(facet), facets);

        // Set facet selectors
        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = bytes4(0x12345678);
        MoreVaultsStorageHelper.setFacetFunctionSelectors(
            address(facet),
            facet1,
            selectors1,
            0
        );

        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(0x87654321);
        MoreVaultsStorageHelper.setFacetFunctionSelectors(
            address(facet),
            facet2,
            selectors2,
            0
        );

        // Mock registry behavior
        vm.mockCall(
            newRegistry,
            abi.encodeWithSelector(IMoreVaultsRegistry.isFacetAllowed.selector),
            abi.encode(true)
        );
        vm.mockCall(
            newRegistry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.selectorToFacet.selector
            ),
            abi.encode(facet1)
        );

        // Mock validateRegistryOwner to return true for registry address
        vm.mockCall(
            address(registry),
            abi.encodeWithSelector(IAccessControl.hasRole.selector),
            abi.encode(true)
        );
    }

    function test_facetName_ShouldReturnCorrectName() public view {
        assertEq(
            facet.facetName(),
            "AccessControlFacet",
            "Facet name should be correct"
        );
    }

    function test_transferCuratorship_ShouldUpdateCurator() public {
        vm.startPrank(curator);

        // Transfer curatorship
        facet.transferCuratorship(newCurator);

        // Verify new curator in storage
        bytes32 newCuratorSlot = vm.load(
            address(facet),
            bytes32(uint256(ACCESS_CONTROL_STORAGE_POSITION) + 0)
        );
        assertEq(
            address(uint160(uint256(newCuratorSlot))),
            newCurator,
            "Curator should be updated in storage"
        );

        // Verify through getter
        assertEq(facet.curator(), newCurator, "Curator should be updated");

        vm.stopPrank();
    }

    function test_transferCuratorship_ShouldRevertWhenUnauthorized() public {
        vm.startPrank(unauthorized);

        // Attempt to transfer curatorship
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        facet.transferCuratorship(newCurator);

        // Verify curator remains unchanged in storage
        bytes32 curatorSlot = vm.load(
            address(facet),
            bytes32(uint256(ACCESS_CONTROL_STORAGE_POSITION) + 0)
        );
        assertEq(
            address(uint160(uint256(curatorSlot))),
            curator,
            "Curator should not be changed in storage"
        );

        // Verify through getter
        assertEq(facet.curator(), curator, "Curator should not be changed");

        vm.stopPrank();
    }

    function test_transferCuratorship_ShouldRevertWhenZeroAddress() public {
        vm.startPrank(curator);

        // Attempt to transfer curatorship to zero address
        vm.expectRevert(AccessControlLib.ZeroAddress.selector);
        facet.transferCuratorship(address(0));

        vm.stopPrank();
    }

    function test_transferCuratorship_ShouldRevertWhenSameAddress() public {
        vm.startPrank(curator);

        // Attempt to transfer curatorship to same address
        vm.expectRevert(AccessControlLib.SameAddress.selector);
        facet.transferCuratorship(curator);

        vm.stopPrank();
    }

    function test_transferGuardian_ShouldUpdateGuardian() public {
        vm.startPrank(guardian);

        // Transfer guardian role
        facet.transferGuardian(newGuardian);

        // Verify new guardian in storage
        bytes32 newGuardianSlot = vm.load(
            address(facet),
            bytes32(uint256(ACCESS_CONTROL_STORAGE_POSITION) + 1)
        );
        assertEq(
            address(uint160(uint256(newGuardianSlot))),
            newGuardian,
            "Guardian should be updated in storage"
        );

        // Verify through getter
        assertEq(facet.guardian(), newGuardian, "Guardian should be updated");

        vm.stopPrank();
    }

    function test_transferGuardian_ShouldRevertWhenUnauthorized() public {
        vm.startPrank(unauthorized);

        // Attempt to transfer guardian role
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        facet.transferGuardian(newGuardian);

        // Verify guardian remains unchanged in storage
        bytes32 guardianSlot = vm.load(
            address(facet),
            bytes32(uint256(ACCESS_CONTROL_STORAGE_POSITION) + 1)
        );
        assertEq(
            address(uint160(uint256(guardianSlot))),
            guardian,
            "Guardian should not be changed in storage"
        );

        // Verify through getter
        assertEq(facet.guardian(), guardian, "Guardian should not be changed");

        vm.stopPrank();
    }

    function test_transferGuardian_ShouldRevertWhenZeroAddress() public {
        vm.startPrank(guardian);

        // Attempt to transfer guardian role to zero address
        vm.expectRevert(AccessControlLib.ZeroAddress.selector);
        facet.transferGuardian(address(0));

        vm.stopPrank();
    }

    function test_transferGuardian_ShouldRevertWhenSameAddress() public {
        vm.startPrank(guardian);

        // Attempt to transfer guardian role to same address
        vm.expectRevert(AccessControlLib.SameAddress.selector);
        facet.transferGuardian(guardian);

        vm.stopPrank();
    }

    function test_curator_ShouldReturnCorrectAddress() public view {
        // Verify curator in storage
        bytes32 curatorSlot = vm.load(
            address(facet),
            bytes32(uint256(ACCESS_CONTROL_STORAGE_POSITION) + 0)
        );
        assertEq(
            address(uint160(uint256(curatorSlot))),
            curator,
            "Curator should be correct in storage"
        );

        // Verify through getter
        assertEq(facet.curator(), curator, "Curator should be correct");
    }

    function test_guardian_ShouldReturnCorrectAddress() public view {
        // Verify guardian in storage
        bytes32 guardianSlot = vm.load(
            address(facet),
            bytes32(uint256(ACCESS_CONTROL_STORAGE_POSITION) + 1)
        );
        assertEq(
            address(uint160(uint256(guardianSlot))),
            guardian,
            "Guardian should be correct in storage"
        );

        // Verify through getter
        assertEq(facet.guardian(), guardian, "Guardian should be correct");
    }

    function test_setMoreVaultRegistry_ShouldUpdateRegistry() public {
        vm.startPrank(registry);

        // Mock selectorToFacet to return different facets for different selectors
        vm.mockCall(
            newRegistry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.selectorToFacet.selector,
                bytes4(0x12345678)
            ),
            abi.encode(facet1)
        );
        vm.mockCall(
            newRegistry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.selectorToFacet.selector,
                bytes4(0x87654321)
            ),
            abi.encode(facet2)
        );

        // Set new registry
        facet.setMoreVaultRegistry(newRegistry);

        // Verify new registry in storage
        bytes32 newRegistrySlot = vm.load(
            address(facet),
            bytes32(uint256(ACCESS_CONTROL_STORAGE_POSITION) + 2)
        );
        assertEq(
            address(uint160(uint256(newRegistrySlot))),
            newRegistry,
            "Registry should be updated in storage"
        );

        vm.stopPrank();
    }

    function test_setMoreVaultRegistry_ShouldRevertWhenUnauthorized() public {
        vm.startPrank(unauthorized);

        // Mock validateRegistryOwner to revert for unauthorized address
        vm.mockCall(
            address(registry),
            abi.encodeWithSelector(IAccessControl.hasRole.selector),
            abi.encode(false)
        );

        // Attempt to set new registry
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        facet.setMoreVaultRegistry(newRegistry);

        // Verify registry remains unchanged in storage
        bytes32 registrySlot = vm.load(
            address(facet),
            bytes32(uint256(ACCESS_CONTROL_STORAGE_POSITION) + 2)
        );
        assertEq(
            address(uint160(uint256(registrySlot))),
            registry,
            "Registry should not be changed in storage"
        );

        vm.stopPrank();
    }

    function test_setMoreVaultRegistry_ShouldRevertWhenZeroAddress() public {
        vm.startPrank(registry);

        // Attempt to set zero address as registry
        vm.expectRevert(AccessControlLib.ZeroAddress.selector);
        facet.setMoreVaultRegistry(address(0));

        vm.stopPrank();
    }

    function test_setMoreVaultRegistry_ShouldRevertWhenSameAddress() public {
        vm.startPrank(registry);

        // Attempt to set same registry address
        vm.expectRevert(AccessControlLib.SameAddress.selector);
        facet.setMoreVaultRegistry(registry);

        vm.stopPrank();
    }

    function test_setMoreVaultRegistry_ShouldRevertWhenFacetNotAllowed()
        public
    {
        vm.startPrank(registry);

        // Mock registry to return false for isFacetAllowed
        vm.mockCall(
            newRegistry,
            abi.encodeWithSelector(IMoreVaultsRegistry.isFacetAllowed.selector),
            abi.encode(false)
        );

        // Attempt to set new registry
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlFacet.VaultHasNotAllowedFacet.selector,
                address(facet1)
            )
        );
        facet.setMoreVaultRegistry(newRegistry);

        vm.stopPrank();
    }

    function test_setMoreVaultRegistry_ShouldRevertWhenSelectorNotAllowed()
        public
    {
        vm.startPrank(registry);

        // Mock registry to return different facet for selector
        vm.mockCall(
            newRegistry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.selectorToFacet.selector
            ),
            abi.encode(facet2)
        );

        // Attempt to set new registry
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlFacet.VaultHasNotAllowedSelector.selector,
                address(facet1),
                bytes4(0x12345678)
            )
        );
        facet.setMoreVaultRegistry(newRegistry);

        vm.stopPrank();
    }
}

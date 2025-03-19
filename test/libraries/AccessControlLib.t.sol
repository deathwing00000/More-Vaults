// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {AccessControlLib} from "../../src/libraries/AccessControlLib.sol";
import {MoreVaultsStorageHelper} from "./MoreVaultsStorageHelper.sol";
import {IMoreVaultsRegistry} from "../../src/interfaces/IMoreVaultsRegistry.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract MockAccessControl {
    function validateRegistryOwner(address caller) external view {
        AccessControlLib.validateRegistryOwner(caller);
    }
}

contract AccessControlLibTest is Test {
    address public curator = address(1);
    address public guardian = address(2);
    address public registry = address(3);
    address public unauthorized = address(4);
    address public zeroAddress = address(0);
    MockAccessControl public mockAccessControl;

    function setUp() public {
        // Deploy mock contract
        mockAccessControl = new MockAccessControl();

        // Set initial values in storage
        MoreVaultsStorageHelper.setCurator(address(this), curator);
        MoreVaultsStorageHelper.setGuardian(address(this), guardian);
        MoreVaultsStorageHelper.setMoreVaultsRegistry(address(this), registry);

        MoreVaultsStorageHelper.setCurator(address(mockAccessControl), curator);
        MoreVaultsStorageHelper.setGuardian(
            address(mockAccessControl),
            guardian
        );
        MoreVaultsStorageHelper.setMoreVaultsRegistry(
            address(mockAccessControl),
            registry
        );
    }

    function test_validateCurator_ShouldNotRevertWhenCallerIsCurator() public {
        vm.startPrank(curator);
        AccessControlLib.validateCurator(curator);
        vm.stopPrank();
    }

    function test_validateCurator_ShouldRevertWhenCallerIsNotCurator() public {
        vm.startPrank(unauthorized);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AccessControlLib.validateCurator(unauthorized);
        vm.stopPrank();
    }

    function test_validateGuardian_ShouldNotRevertWhenCallerIsGuardian()
        public
    {
        vm.startPrank(guardian);
        AccessControlLib.validateGuardian(guardian);
        vm.stopPrank();
    }

    function test_validateGuardian_ShouldRevertWhenCallerIsNotGuardian()
        public
    {
        vm.startPrank(unauthorized);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AccessControlLib.validateGuardian(unauthorized);
        vm.stopPrank();
    }

    function test_validateDiamond_ShouldNotRevertWhenCallerIsDiamond()
        public
        view
    {
        AccessControlLib.validateDiamond(address(this));
    }

    function test_validateDiamond_ShouldRevertWhenCallerIsNotDiamond() public {
        vm.startPrank(unauthorized);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        AccessControlLib.validateDiamond(unauthorized);
        vm.stopPrank();
    }

    function test_setVaultCurator_ShouldSetNewCurator() public {
        address newCurator = address(5);
        AccessControlLib.setVaultCurator(newCurator);
        assertEq(
            AccessControlLib.vaultCurator(),
            newCurator,
            "Curator should be updated"
        );
    }

    function test_setVaultCurator_ShouldRevertWhenZeroAddress() public {
        vm.expectRevert(AccessControlLib.ZeroAddress.selector);
        AccessControlLib.setVaultCurator(zeroAddress);
    }

    function test_setVaultCurator_ShouldRevertWhenSameAddress() public {
        vm.expectRevert(AccessControlLib.SameAddress.selector);
        AccessControlLib.setVaultCurator(curator);
    }

    function test_setVaultGuardian_ShouldSetNewGuardian() public {
        address newGuardian = address(5);
        AccessControlLib.setVaultGuardian(newGuardian);
        assertEq(
            AccessControlLib.vaultGuardian(),
            newGuardian,
            "Guardian should be updated"
        );
    }

    function test_setVaultGuardian_ShouldRevertWhenZeroAddress() public {
        vm.expectRevert(AccessControlLib.ZeroAddress.selector);
        AccessControlLib.setVaultGuardian(zeroAddress);
    }

    function test_setVaultGuardian_ShouldRevertWhenSameAddress() public {
        vm.expectRevert(AccessControlLib.SameAddress.selector);
        AccessControlLib.setVaultGuardian(guardian);
    }

    function test_vaultCurator_ShouldReturnCorrectCurator() public view {
        assertEq(
            AccessControlLib.vaultCurator(),
            curator,
            "Should return correct curator"
        );
    }

    function test_vaultGuardian_ShouldReturnCorrectGuardian() public view {
        assertEq(
            AccessControlLib.vaultGuardian(),
            guardian,
            "Should return correct guardian"
        );
    }

    function test_vaultRegistry_ShouldReturnCorrectRegistry() public view {
        assertEq(
            AccessControlLib.vaultRegistry(),
            registry,
            "Should return correct registry"
        );
    }

    function test_validateRegistryOwner_ShouldNotRevertWhenCallerHasRole()
        public
    {
        // Mock IAccessControl.hasRole to return true
        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IAccessControl.hasRole.selector,
                bytes32(0),
                curator
            ),
            abi.encode(true)
        );

        vm.startPrank(curator);
        AccessControlLib.validateRegistryOwner(curator);
        vm.stopPrank();
    }

    function test_validateRegistryOwner_ShouldRevertWhenCallerDoesNotHaveRole()
        public
    {
        // Mock IAccessControl.hasRole to return false
        bytes memory callData = abi.encodeWithSelector(
            IAccessControl.hasRole.selector,
            bytes32(0),
            unauthorized
        );
        vm.mockCall(registry, callData, abi.encode(false));

        vm.startPrank(unauthorized);
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        mockAccessControl.validateRegistryOwner(unauthorized);
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {ConfigurationFacet} from "../src/facets/ConfigurationFacet.sol";
import {IConfigurationFacet} from "../src/interfaces/facets/IConfigurationFacet.sol";
import {AccessControlLib} from "../src/libraries/AccessControlLib.sol";
import {MoreVaultsStorageHelper} from "./libraries/MoreVaultsStorageHelper.sol";

contract ConfigurationFacetTest is Test {
    ConfigurationFacet public facet;

    address public curator = address(1);
    address public unauthorized = address(2);
    address public newFeeRecipient = address(3);
    address public asset1 = address(4);
    address public asset2 = address(5);
    address public zeroAddress = address(0);

    // Storage slot for AccessControlStorage struct
    bytes32 constant ACCESS_CONTROL_STORAGE_POSITION =
        AccessControlLib.ACCESS_CONTROL_STORAGE_POSITION;

    function setUp() public {
        // Deploy facet
        facet = new ConfigurationFacet();

        // Set curator role
        vm.store(
            address(facet),
            bytes32(uint256(ACCESS_CONTROL_STORAGE_POSITION) + 0),
            bytes32(uint256(uint160(curator)))
        );

        // Set initial values using helper library
        MoreVaultsStorageHelper.setFeeRecipient(address(facet), address(1));
        MoreVaultsStorageHelper.setFee(address(facet), 100); // 1%
        MoreVaultsStorageHelper.setTimeLockPeriod(address(facet), 1 days);
    }

    function test_facetName_ShouldReturnCorrectName() public view {
        assertEq(
            facet.facetName(),
            "ConfigurationFacet",
            "Facet name should be correct"
        );
    }

    function test_setFeeRecipient_ShouldUpdateRecipient() public {
        vm.startPrank(curator);

        // Set new fee recipient
        facet.setFeeRecipient(newFeeRecipient);

        // Verify through getter
        assertEq(
            MoreVaultsStorageHelper.getFeeRecipient(address(facet)),
            newFeeRecipient,
            "Fee recipient should be updated"
        );

        vm.stopPrank();
    }

    function test_setFeeRecipient_ShouldRevertWhenUnauthorized() public {
        vm.startPrank(unauthorized);

        // Attempt to set new fee recipient
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        facet.setFeeRecipient(newFeeRecipient);

        // Verify fee recipient remains unchanged
        assertEq(
            MoreVaultsStorageHelper.getFeeRecipient(address(facet)),
            address(1),
            "Fee recipient should not be changed"
        );

        vm.stopPrank();
    }

    function test_setFeeRecipient_ShouldRevertWhenZeroAddress() public {
        vm.startPrank(curator);

        // Attempt to set zero address as fee recipient
        vm.expectRevert(IConfigurationFacet.InvalidAddress.selector);
        facet.setFeeRecipient(zeroAddress);

        vm.stopPrank();
    }

    function test_setFee_ShouldUpdateFee() public {
        vm.startPrank(curator);

        // Set new fee
        uint96 newFee = 200; // 2%
        facet.setFee(newFee);

        // Verify through getter
        assertEq(
            MoreVaultsStorageHelper.getFee(address(facet)),
            newFee,
            "Fee should be updated"
        );

        vm.stopPrank();
    }

    function test_setFee_ShouldRevertWhenUnauthorized() public {
        vm.startPrank(unauthorized);

        // Attempt to set new fee
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        facet.setFee(200);

        // Verify fee remains unchanged
        assertEq(
            MoreVaultsStorageHelper.getFee(address(facet)),
            100,
            "Fee should not be changed"
        );

        vm.stopPrank();
    }

    function test_setFee_ShouldRevertWhenInvalidFee() public {
        vm.startPrank(curator);

        // Attempt to set fee above 100%
        vm.expectRevert(IConfigurationFacet.InvalidFee.selector);
        facet.setFee(10001);

        vm.stopPrank();
    }

    function test_setTimeLockPeriod_ShouldUpdatePeriod() public {
        vm.startPrank(curator);

        // Set new time lock period
        uint256 newPeriod = 2 days;
        facet.setTimeLockPeriod(newPeriod);

        // Verify through getter
        assertEq(
            MoreVaultsStorageHelper.getTimeLockPeriod(address(facet)),
            newPeriod,
            "Time lock period should be updated"
        );

        vm.stopPrank();
    }

    function test_setTimeLockPeriod_ShouldRevertWhenUnauthorized() public {
        vm.startPrank(unauthorized);

        // Attempt to set new time lock period
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        facet.setTimeLockPeriod(2 days);

        // Verify time lock period remains unchanged
        assertEq(
            MoreVaultsStorageHelper.getTimeLockPeriod(address(facet)),
            1 days,
            "Time lock period should not be changed"
        );

        vm.stopPrank();
    }

    function test_setTimeLockPeriod_ShouldRevertWhenZeroPeriod() public {
        vm.startPrank(curator);

        // Attempt to set zero period
        vm.expectRevert(IConfigurationFacet.InvalidPeriod.selector);
        facet.setTimeLockPeriod(0);

        vm.stopPrank();
    }

    function test_addAvailableAsset_ShouldAddAsset() public {
        vm.startPrank(curator);

        // Add new asset
        facet.addAvailableAsset(asset1);

        // Verify asset is available
        assertTrue(
            MoreVaultsStorageHelper.isAssetAvailable(address(facet), asset1),
            "Asset should be available"
        );

        // Verify asset is in available assets array
        address[] memory assets = MoreVaultsStorageHelper.getAvailableAssets(
            address(facet)
        );
        assertEq(
            assets.length,
            1,
            "Available assets array should have one element"
        );
        assertEq(
            assets[0],
            asset1,
            "Asset should be in available assets array"
        );

        vm.stopPrank();
    }

    function test_addAvailableAsset_ShouldRevertWhenUnauthorized() public {
        vm.startPrank(unauthorized);

        // Attempt to add new asset
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        facet.addAvailableAsset(asset1);

        // Verify asset is not available
        assertFalse(
            MoreVaultsStorageHelper.isAssetAvailable(address(facet), asset1),
            "Asset should not be available"
        );

        vm.stopPrank();
    }

    function test_addAvailableAsset_ShouldRevertWhenZeroAddress() public {
        vm.startPrank(curator);

        // Attempt to add zero address as asset
        vm.expectRevert(IConfigurationFacet.InvalidAddress.selector);
        facet.addAvailableAsset(zeroAddress);

        vm.stopPrank();
    }

    function test_addAvailableAsset_ShouldRevertWhenAssetAlreadyAvailable()
        public
    {
        vm.startPrank(curator);

        // Add asset first time
        facet.addAvailableAsset(asset1);

        // Attempt to add same asset again
        vm.expectRevert(IConfigurationFacet.AssetAlreadyAvailable.selector);
        facet.addAvailableAsset(asset1);

        vm.stopPrank();
    }

    function test_addAvailableAssets_ShouldAddAssets() public {
        vm.startPrank(curator);

        // Prepare assets array
        address[] memory assets = new address[](2);
        assets[0] = asset1;
        assets[1] = asset2;

        // Add assets
        facet.addAvailableAssets(assets);

        // Verify assets are available
        assertTrue(
            MoreVaultsStorageHelper.isAssetAvailable(address(facet), asset1),
            "Asset1 should be available"
        );
        assertTrue(
            MoreVaultsStorageHelper.isAssetAvailable(address(facet), asset2),
            "Asset2 should be available"
        );

        // Verify assets are in available assets array
        address[] memory availableAssets = MoreVaultsStorageHelper
            .getAvailableAssets(address(facet));
        assertEq(
            availableAssets.length,
            2,
            "Available assets array should have two elements"
        );
        assertEq(
            availableAssets[0],
            asset1,
            "Asset1 should be in available assets array"
        );
        assertEq(
            availableAssets[1],
            asset2,
            "Asset2 should be in available assets array"
        );

        vm.stopPrank();
    }

    function test_addAvailableAssets_ShouldRevertWhenUnauthorized() public {
        vm.startPrank(unauthorized);

        // Prepare assets array
        address[] memory assets = new address[](2);
        assets[0] = asset1;
        assets[1] = asset2;

        // Attempt to add assets
        vm.expectRevert(AccessControlLib.UnauthorizedAccess.selector);
        facet.addAvailableAssets(assets);

        // Verify assets are not available
        assertFalse(
            MoreVaultsStorageHelper.isAssetAvailable(address(facet), asset1),
            "Asset1 should not be available"
        );
        assertFalse(
            MoreVaultsStorageHelper.isAssetAvailable(address(facet), asset2),
            "Asset2 should not be available"
        );

        vm.stopPrank();
    }

    function test_addAvailableAssets_ShouldRevertWhenZeroAddress() public {
        vm.startPrank(curator);

        // Prepare assets array with zero address
        address[] memory assets = new address[](2);
        assets[0] = asset1;
        assets[1] = zeroAddress;

        // Attempt to add assets
        vm.expectRevert(IConfigurationFacet.InvalidAddress.selector);
        facet.addAvailableAssets(assets);

        vm.stopPrank();
    }

    function test_isAssetAvailable_ShouldReturnCorrectValue() public {
        vm.startPrank(curator);

        // Add asset
        facet.addAvailableAsset(asset1);

        // Verify asset is available
        assertTrue(facet.isAssetAvailable(asset1), "Asset should be available");

        // Verify non-existent asset is not available
        assertFalse(
            facet.isAssetAvailable(asset2),
            "Asset should not be available"
        );

        vm.stopPrank();
    }

    function test_getAvailableAssets_ShouldReturnCorrectArray() public {
        vm.startPrank(curator);

        // Add assets
        facet.addAvailableAsset(asset1);
        facet.addAvailableAsset(asset2);

        // Get available assets
        address[] memory assets = facet.getAvailableAssets();

        // Verify array
        assertEq(assets.length, 2, "Array should have two elements");
        assertEq(assets[0], asset1, "First element should be asset1");
        assertEq(assets[1], asset2, "Second element should be asset2");

        vm.stopPrank();
    }
}

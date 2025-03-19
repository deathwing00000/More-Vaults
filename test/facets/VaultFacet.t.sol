// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {VaultFacet} from "../../src/facets/VaultFacet.sol";
import {MoreVaultsStorageHelper} from "../libraries/MoreVaultsStorageHelper.sol";
import {IVaultFacet} from "../../src/interfaces/facets/IVaultFacet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC165} from "../../src/interfaces/IERC165.sol";
import {IERC173} from "../../src/interfaces/IERC173.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IConfigurationFacet} from "../../src/interfaces/facets/IConfigurationFacet.sol";
import {IDiamondCut} from "../../src/interfaces/facets/IDiamondCut.sol";
import {IDiamondLoupe} from "../../src/interfaces/facets/IDiamondLoupe.sol";
import {IMulticallFacet} from "../../src/interfaces/facets/IMulticallFacet.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {BaseFacetInitializer} from "../../src/facets/BaseFacetInitializer.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract VaultFacetTest is Test {
    // Test addresses
    address public facet;
    address public curator = address(7);
    address public guardian = address(8);
    address public feeRecipient = address(9);
    address public registry = address(1000);
    address public asset;
    address public user = address(1);

    // Test data
    string constant VAULT_NAME = "Test Vault";
    string constant VAULT_SYMBOL = "TV";
    uint96 constant FEE = 1000; // 10%
    uint256 constant TIME_LOCK_PERIOD = 1 days;

    address public aaveOracleProvider = address(1001);
    address public oracle = address(1002);

    function setUp() public {
        // Deploy facet
        VaultFacet vaultFacet = new VaultFacet();
        facet = address(vaultFacet);

        // Deploy mock asset
        MockERC20 mockAsset = new MockERC20("Test Asset", "TA");
        asset = address(mockAsset);

        // Initialize vault
        bytes memory initData = abi.encode(
            VAULT_NAME,
            VAULT_SYMBOL,
            asset,
            registry,
            curator,
            guardian,
            feeRecipient,
            FEE,
            TIME_LOCK_PERIOD
        );
        VaultFacet(facet).initialize(initData);

        // Setup initial state
        MoreVaultsStorageHelper.setMoreVaultsRegistry(facet, registry);
        MoreVaultsStorageHelper.setCurator(facet, curator);
        MoreVaultsStorageHelper.setGuardian(facet, guardian);
        MoreVaultsStorageHelper.setFeeRecipient(facet, feeRecipient);
        MoreVaultsStorageHelper.setFee(facet, FEE);
        MoreVaultsStorageHelper.setTimeLockPeriod(facet, TIME_LOCK_PERIOD);

        // Setup supported interfaces
        MoreVaultsStorageHelper.setSupportedInterface(
            facet,
            type(IERC165).interfaceId,
            true
        );
        MoreVaultsStorageHelper.setSupportedInterface(
            facet,
            type(IERC173).interfaceId,
            true
        );
        MoreVaultsStorageHelper.setSupportedInterface(
            facet,
            type(IAccessControl).interfaceId,
            true
        );
        MoreVaultsStorageHelper.setSupportedInterface(
            facet,
            type(IConfigurationFacet).interfaceId,
            true
        );
        MoreVaultsStorageHelper.setSupportedInterface(
            facet,
            type(IDiamondCut).interfaceId,
            true
        );
        MoreVaultsStorageHelper.setSupportedInterface(
            facet,
            type(IDiamondLoupe).interfaceId,
            true
        );
        MoreVaultsStorageHelper.setSupportedInterface(
            facet,
            type(IMulticallFacet).interfaceId,
            true
        );
        MoreVaultsStorageHelper.setSupportedInterface(
            facet,
            type(IERC4626).interfaceId,
            true
        );
        MoreVaultsStorageHelper.setSupportedInterface(
            facet,
            type(IVaultFacet).interfaceId,
            true
        );

        // Mint some assets to user for testing
        MockERC20(asset).mint(user, 1000 ether);
        vm.prank(user);
        IERC20(asset).approve(facet, type(uint256).max);
    }

    function test_initialize_ShouldSetInitialValues() public view {
        assertEq(
            IERC20Metadata(facet).name(),
            VAULT_NAME,
            "Should set correct name"
        );
        assertEq(
            IERC20Metadata(facet).symbol(),
            VAULT_SYMBOL,
            "Should set correct symbol"
        );
        assertEq(
            IERC20Metadata(facet).decimals(),
            18,
            "Should set correct decimals"
        );
        assertEq(
            MoreVaultsStorageHelper.getFeeRecipient(facet),
            feeRecipient,
            "Should set correct fee recipient"
        );
        assertEq(
            MoreVaultsStorageHelper.getFee(facet),
            FEE,
            "Should set correct fee"
        );
        assertEq(
            MoreVaultsStorageHelper.getTimeLockPeriod(facet),
            TIME_LOCK_PERIOD,
            "Should set correct time lock period"
        );
    }

    function test_initialize_ShouldRevertWithInvalidParameters() public {
        VaultFacet newFacet = new VaultFacet();
        bytes memory initData = abi.encode(
            VAULT_NAME,
            VAULT_SYMBOL,
            address(0), // Invalid asset
            registry,
            curator,
            guardian,
            feeRecipient,
            FEE,
            TIME_LOCK_PERIOD
        );
        vm.expectRevert(BaseFacetInitializer.InvalidParameters.selector);
        VaultFacet(address(newFacet)).initialize(initData);
    }

    function test_deposit_ShouldMintShares() public {
        uint256 depositAmount = 100 ether;

        // Mock oracle call
        vm.mockCall(
            registry,
            abi.encodeWithSignature("oracle()"),
            abi.encode(aaveOracleProvider)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("getDenominationAsset()"),
            abi.encode(asset)
        );
        vm.mockCall(
            aaveOracleProvider,
            abi.encodeWithSignature("getSourceOfAsset(address)"),
            abi.encode(oracle)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("latestAnswer()"),
            abi.encode(1 ether)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );

        vm.prank(user);
        uint256 shares = VaultFacet(facet).deposit(depositAmount, user);

        assertEq(
            IERC20(facet).balanceOf(user),
            shares,
            "Should mint correct amount of shares"
        );
        assertEq(
            IERC20(asset).balanceOf(facet),
            depositAmount,
            "Should receive correct amount of assets"
        );
    }

    function test_withdraw_ShouldBurnShares() public {
        // Mock oracle call
        vm.mockCall(
            registry,
            abi.encodeWithSignature("oracle()"),
            abi.encode(aaveOracleProvider)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("getDenominationAsset()"),
            abi.encode(asset)
        );
        vm.mockCall(
            aaveOracleProvider,
            abi.encodeWithSignature("getSourceOfAsset(address)"),
            abi.encode(oracle)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("latestAnswer()"),
            abi.encode(1 ether)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );

        // First deposit
        uint256 depositAmount = 100 ether;
        vm.prank(user);
        VaultFacet(facet).deposit(depositAmount, user);
        // Then withdraw
        // Mock oracle call
        vm.mockCall(
            registry,
            abi.encodeWithSignature("oracle()"),
            abi.encode(aaveOracleProvider)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("getDenominationAsset()"),
            abi.encode(asset)
        );
        vm.mockCall(
            aaveOracleProvider,
            abi.encodeWithSignature("getSourceOfAsset(address)"),
            abi.encode(oracle)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("latestAnswer()"),
            abi.encode(1 ether)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );

        uint256 withdrawAmount = 50 ether;
        vm.prank(user);
        VaultFacet(facet).withdraw(withdrawAmount, user, user);

        assertEq(
            IERC20(asset).balanceOf(user),
            950 ether,
            "Should return correct amount of assets"
        );
        assertEq(
            IERC20(facet).balanceOf(user),
            50 ether,
            "Should burn correct amount of shares"
        );
    }

    function test_pause_ShouldRevertWhenNotCurator() public {
        vm.prank(user);
        vm.expectRevert();
        VaultFacet(facet).pause();
    }

    function test_pause_ShouldPauseVault() public {
        vm.prank(curator);
        VaultFacet(facet).pause();
        assertTrue(VaultFacet(facet).paused(), "Should be paused");
    }

    function test_unpause_ShouldUnpauseVault() public {
        // First pause
        vm.prank(curator);
        VaultFacet(facet).pause();

        // Then unpause
        vm.prank(curator);
        VaultFacet(facet).unpause();
        assertFalse(VaultFacet(facet).paused(), "Should be unpaused");
    }

    function test_deposit_ShouldRevertWhenPaused() public {
        // Pause vault
        vm.prank(curator);
        VaultFacet(facet).pause();

        // Try to deposit
        vm.prank(user);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        VaultFacet(facet).deposit(100 ether, user);
    }
}

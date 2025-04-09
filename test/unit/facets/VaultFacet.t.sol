// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {VaultFacet} from "../../../src/facets/VaultFacet.sol";
import {MoreVaultsStorageHelper} from "../../helper/MoreVaultsStorageHelper.sol";
import {IVaultFacet} from "../../../src/interfaces/facets/IVaultFacet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC165} from "../../../src/interfaces/IERC165.sol";
import {IERC173} from "../../../src/interfaces/IERC173.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IConfigurationFacet} from "../../../src/interfaces/facets/IConfigurationFacet.sol";
import {IDiamondCut} from "../../../src/interfaces/facets/IDiamondCut.sol";
import {IDiamondLoupe} from "../../../src/interfaces/facets/IDiamondLoupe.sol";
import {IMulticallFacet} from "../../../src/interfaces/facets/IMulticallFacet.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {BaseFacetInitializer} from "../../../src/facets/BaseFacetInitializer.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IAaveOracle} from "@aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {IMoreVaultsRegistry} from "../../../src/interfaces/IMoreVaultsRegistry.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract VaultFacetTest is Test {
    using Math for uint256;

    // Test addresses
    address public facet;
    address public owner = address(9999);
    address public curator = address(7);
    address public guardian = address(8);
    address public feeRecipient = address(9);
    address public registry = address(1000);
    address public asset;
    address public user = address(1);

    // Test data
    string constant VAULT_NAME = "Test Vault";
    string constant VAULT_SYMBOL = "TV";
    uint96 constant FEE_BASIS_POINT = 10000;
    uint96 constant FEE = 1000; // 10%
    uint256 constant TIME_LOCK_PERIOD = 1 days;

    address public aaveOracleProvider = address(1001);
    address public oracle = address(1002);

    address public protocolFeeRecipient = address(1003);
    uint96 public protocolFee = 1000; // 10%

    function setUp() public {
        vm.warp(block.timestamp + 1 days);

        // Deploy facet
        VaultFacet vaultFacet = new VaultFacet();
        facet = address(vaultFacet);

        // Deploy mock asset
        MockERC20 mockAsset = new MockERC20("Test Asset", "TA");
        asset = address(mockAsset);

        MoreVaultsStorageHelper.setMoreVaultsRegistry(facet, registry);
        MoreVaultsStorageHelper.setOwner(facet, owner);

        // Initialize vault
        bytes memory initData = abi.encode(
            VAULT_NAME,
            VAULT_SYMBOL,
            asset,
            feeRecipient,
            FEE
        );

        vm.mockCall(
            address(registry),
            abi.encodeWithSelector(IMoreVaultsRegistry.oracle.selector),
            abi.encode(oracle)
        );

        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(
                IAaveOracle.getSourceOfAsset.selector,
                asset
            ),
            abi.encode(address(2000))
        );

        VaultFacet(facet).initialize(initData);

        // // Setup initial state
        MoreVaultsStorageHelper.setMoreVaultsRegistry(facet, registry);
        MoreVaultsStorageHelper.setCurator(facet, curator);
        MoreVaultsStorageHelper.setGuardian(facet, guardian);

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
            MoreVaultsStorageHelper.isAssetAvailable(facet, asset),
            true,
            "Should set asset available"
        );

        assertTrue(
            MoreVaultsStorageHelper.getSupportedInterface(
                facet,
                type(IVaultFacet).interfaceId
            ),
            "Should set supported interface"
        );
        assertTrue(
            MoreVaultsStorageHelper.getSupportedInterface(
                facet,
                type(IERC4626).interfaceId
            ),
            "Should set supported interface"
        );
        assertTrue(
            MoreVaultsStorageHelper.getSupportedInterface(
                facet,
                type(IERC20).interfaceId
            ),
            "Should set supported interface"
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

    function test_facetName_ShouldReturnCorrectName() public view {
        assertEq(
            VaultFacet(facet).facetName(),
            "VaultFacet",
            "Should return correct facet name"
        );
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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1 ether, block.timestamp, block.timestamp, 0)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(address(0), 0)
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

    function test_deposit_ShouldMintSharesWithMultipleAssets() public {
        MockERC20 mockAsset2 = new MockERC20("Test Asset 2", "TA2");
        address asset2 = address(mockAsset2);
        uint256 depositAmount = 100 ether;
        uint256 depositAmount2 = 200 ether;

        MockERC20(asset2).mint(user, depositAmount2);
        vm.prank(user);
        IERC20(asset2).approve(facet, type(uint256).max);

        address[] memory tokens = new address[](2);
        tokens[0] = asset;
        tokens[1] = asset2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = depositAmount;
        amounts[1] = depositAmount2;
        MoreVaultsStorageHelper.setAvailableAssets(facet, tokens);
        for (uint256 i = 0; i < tokens.length; i++) {
            MoreVaultsStorageHelper.setDepositableAssets(
                facet,
                tokens[i],
                true
            );
        }

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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1 * 10 ** 8, block.timestamp, block.timestamp, 0)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(address(0), 0)
        );

        vm.prank(user);
        VaultFacet(facet).deposit(tokens, amounts, user);

        // apply generic slippage 1% for conversion of non underlying asset
        uint256 expectedShares = depositAmount + depositAmount2;
        assertEq(
            IERC20(facet).balanceOf(user),
            expectedShares,
            "Should mint correct amount of shares"
        );
        assertEq(
            IERC20(asset).balanceOf(facet),
            depositAmount,
            "Should receive correct amount of assets1"
        );
        assertEq(
            IERC20(asset2).balanceOf(facet),
            depositAmount2,
            "Should receive correct amount of assets2"
        );
    }

    function test_mint_ShouldMintShares() public {
        uint256 mintAmount = 100 ether;

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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1 ether, block.timestamp, block.timestamp, 0)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(address(0), 0)
        );

        vm.prank(user);
        uint256 assets = VaultFacet(facet).mint(mintAmount, user);

        assertEq(
            IERC20(facet).balanceOf(user),
            mintAmount,
            "Should mint correct amount of shares"
        );
        assertEq(
            IERC20(asset).balanceOf(facet),
            assets,
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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1 ether, block.timestamp, block.timestamp, 0)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );

        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(address(0), 0)
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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1 ether, block.timestamp, block.timestamp, 0)
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

    function test_redeem_ShouldBurnShares() public {
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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1 ether, block.timestamp, block.timestamp, 0)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );

        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(address(0), 0)
        );

        // First deposit
        uint256 depositAmount = 100 ether;
        vm.prank(user);
        uint256 shares = VaultFacet(facet).deposit(depositAmount, user);
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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1 ether, block.timestamp, block.timestamp, 0)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );

        uint256 redeemAmount = 50 ether;
        uint256 balanceBefore = IERC20(asset).balanceOf(user);
        vm.prank(user);
        uint256 assets = VaultFacet(facet).redeem(redeemAmount, user, user);

        assertEq(
            IERC20(asset).balanceOf(user),
            balanceBefore + assets,
            "Should return correct amount of assets"
        );
        assertEq(
            IERC20(facet).balanceOf(user),
            shares - redeemAmount,
            "Should burn correct amount of shares"
        );
    }

    function test_pause_ShouldRevertWhenNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        VaultFacet(facet).pause();
    }

    function test_pause_ShouldPauseVault() public {
        vm.prank(owner);
        VaultFacet(facet).pause();
        assertTrue(VaultFacet(facet).paused(), "Should be paused");
    }

    function test_unpause_ShouldUnpauseVault() public {
        // First pause
        vm.prank(owner);
        VaultFacet(facet).pause();

        // Then unpause
        vm.prank(owner);
        VaultFacet(facet).unpause();
        assertFalse(VaultFacet(facet).paused(), "Should be unpaused");
    }

    function test_deposit_ShouldRevertWhenPaused() public {
        // Pause vault
        vm.prank(owner);
        VaultFacet(facet).pause();

        // Try to deposit
        vm.prank(user);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        VaultFacet(facet).deposit(100 ether, user);
    }

    function test_deposit_ShouldRevertWhenPausedWithMultipleAssets() public {
        MockERC20 mockAsset2 = new MockERC20("Test Asset 2", "TA2");
        address asset2 = address(mockAsset2);
        uint256 depositAmount = 100 ether;
        uint256 depositAmount2 = 200 ether;

        MockERC20(asset2).mint(user, depositAmount2);
        vm.prank(user);
        IERC20(asset2).approve(facet, type(uint256).max);

        address[] memory tokens = new address[](2);
        tokens[0] = asset;
        tokens[1] = asset2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = depositAmount;
        amounts[1] = depositAmount2;
        MoreVaultsStorageHelper.setAvailableAssets(facet, tokens);

        // Pause vault
        vm.prank(owner);
        VaultFacet(facet).pause();

        // Try to deposit
        vm.prank(user);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        VaultFacet(facet).deposit(tokens, amounts, user);
    }

    function test_deposit_ShouldRevertWhenDepositWithMultipleAssetsAndArrayLengthsDoesntMatch()
        public
    {
        MockERC20 mockAsset2 = new MockERC20("Test Asset 2", "TA2");
        address asset2 = address(mockAsset2);
        uint256 depositAmount = 100 ether;
        uint256 depositAmount2 = 200 ether;

        MockERC20(asset2).mint(user, depositAmount2);
        vm.prank(user);
        IERC20(asset2).approve(facet, type(uint256).max);

        address[] memory tokens = new address[](2);
        tokens[0] = asset;
        tokens[1] = asset2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = depositAmount;
        amounts[1] = depositAmount2;
        MoreVaultsStorageHelper.setAvailableAssets(facet, tokens);

        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(address(0), 0)
        );

        // Try to deposit
        vm.prank(user);
        uint256[] memory corruptedAmounts = new uint256[](1);
        corruptedAmounts[0] = depositAmount;
        vm.expectRevert(
            abi.encodeWithSelector(
                IVaultFacet.ArraysLengthsDontMatch.selector,
                2,
                1
            )
        );
        VaultFacet(facet).deposit(tokens, corruptedAmounts, user);
    }

    function test_deposit_ShouldRevertWhenDepositWithMultipleAssetsAndAssetIsNotDepositable()
        public
    {
        MockERC20 mockAsset2 = new MockERC20("Test Asset 2", "TA2");
        address asset2 = address(mockAsset2);
        uint256 depositAmount = 100 ether;
        uint256 depositAmount2 = 200 ether;

        MockERC20(asset2).mint(user, depositAmount2);
        vm.prank(user);
        IERC20(asset2).approve(facet, type(uint256).max);

        address[] memory tokens = new address[](2);
        tokens[0] = asset;
        tokens[1] = asset2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = depositAmount;
        amounts[1] = depositAmount2;
        MoreVaultsStorageHelper.setAvailableAssets(facet, tokens);
        MoreVaultsStorageHelper.setDepositableAssets(facet, asset2, false);

        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(address(0), 0)
        );

        // Try to deposit
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVaultFacet.UnsupportedAsset.selector,
                asset2
            )
        );
        VaultFacet(facet).deposit(tokens, amounts, user);
    }

    function test_accrueInterest_ShouldDistributeFeesWithProtocolFee() public {
        // Setup initial deposit
        uint256 depositAmount = 100 ether;
        vm.prank(user);

        // Mock oracle calls for price increase
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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1.1 ether, block.timestamp, block.timestamp, 0) // 10% price increase
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(protocolFeeRecipient, protocolFee)
        );
        uint256 shares = VaultFacet(facet).deposit(depositAmount, user);

        // Move time forward to accrue interest
        vm.warp(block.timestamp + 1 days);

        // Mock oracle calls for price increase
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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1.1 * 10 ** 8, block.timestamp, block.timestamp, 0) // 10% price increase
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(protocolFeeRecipient, protocolFee)
        );

        vm.mockCall(
            oracle,
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1.1 * 10 ** 8, block.timestamp, block.timestamp, 0) // 10% price increase
        );

        // Calculate expected fees
        uint256 totalInterest = 10 ether; // 10% of 100 ether
        uint256 totalFee = (totalInterest * FEE) / FEE_BASIS_POINT; // 10% of interest
        uint256 protocolFeeAmount = (totalFee * protocolFee) / FEE_BASIS_POINT; // 10% of fee
        uint256 vaultFeeAmount = totalFee - protocolFeeAmount;

        MockERC20(asset).mint(facet, totalInterest);

        vm.prank(user);
        uint256 newShares = VaultFacet(facet).deposit(1, user);

        // Check fee distribution
        assertApproxEqAbs(
            IERC20(facet).balanceOf(protocolFeeRecipient),
            VaultFacet(facet).convertToShares(protocolFeeAmount),
            10,
            "Should distribute correct protocol fee"
        );
        assertApproxEqAbs(
            IERC20(facet).balanceOf(feeRecipient),
            VaultFacet(facet).convertToShares(vaultFeeAmount),
            10,
            "Should distribute correct vault fee"
        );
        assertApproxEqAbs(
            IERC20(facet).totalSupply(),
            shares + newShares + VaultFacet(facet).convertToShares(totalFee),
            10,
            "Should increase total supply by fee amount"
        );
    }

    function test_accrueInterest_ShouldDistributeFeesWithoutProtocolFee()
        public
    {
        // Setup initial deposit
        uint256 depositAmount = 100 ether;
        vm.prank(user);
        // Mock oracle calls for price increase
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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1.1 ether, block.timestamp, block.timestamp, 0) // 10% price increase
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(address(0), 0) // No protocol fee
        );
        VaultFacet(facet).deposit(depositAmount, user);

        // Move time forward to accrue interest
        vm.warp(block.timestamp + 1 days);

        // Mock oracle calls for price increase
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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1.1 ether, block.timestamp, block.timestamp, 0) // 10% price increase
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(address(0), 0) // No protocol fee
        );

        // Calculate expected fees
        uint256 totalInterest = 10 ether; // 10% of 100 ether
        uint256 totalFee = (totalInterest * FEE) / FEE_BASIS_POINT; // 10% of interest
        MockERC20(asset).mint(facet, totalInterest);

        // Trigger interest accrual
        vm.prank(user);
        uint256 newShares = VaultFacet(facet).deposit(1, user);

        // Check fee distribution
        assertApproxEqAbs(
            IERC20(facet).balanceOf(feeRecipient),
            VaultFacet(facet).convertToShares(totalFee),
            10,
            "Should distribute all fees to vault fee recipient"
        );
        assertApproxEqAbs(
            IERC20(facet).totalSupply(),
            depositAmount +
                newShares +
                VaultFacet(facet).convertToShares(totalFee),
            10,
            "Should increase total supply by fee amount"
        );
    }

    function test_accrueInterest_ShouldNotDistributeFeesWhenNoFee() public {
        // Setup initial deposit
        uint256 depositAmount = 100 ether;

        // Mock oracle calls for price increase
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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1.1 ether, block.timestamp, block.timestamp, 0) // 10% price increase
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(address(0), 0)
        );
        vm.prank(user);
        VaultFacet(facet).deposit(depositAmount, user);

        // Set fee to 0
        MoreVaultsStorageHelper.setFee(facet, 0);

        // Move time forward to accrue interest
        vm.warp(block.timestamp + 1 days);

        // Mock oracle calls for price increase
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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1.1 ether, block.timestamp, block.timestamp, 0) // 10% price increase
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(address(0), 0)
        );

        // Trigger interest accrual
        vm.prank(user);
        VaultFacet(facet).deposit(0, user);

        // Check that no fees were distributed
        assertEq(
            IERC20(facet).balanceOf(feeRecipient),
            0,
            "Should not distribute any fees"
        );
        assertEq(
            IERC20(facet).totalSupply(),
            depositAmount,
            "Should not mint extra shares for fee"
        );
    }

    function test_accrueInterest_ShouldNotDistributeFeesWhenInterestIsZero()
        public
    {
        // Setup initial deposit
        uint256 depositAmount = 100 ether;

        // Mock oracle calls for price increase
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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1.1 ether, block.timestamp, block.timestamp, 0) // 10% price increase
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(address(0), 0)
        );
        vm.prank(user);
        VaultFacet(facet).deposit(depositAmount, user);

        // Move time forward to accrue interest
        vm.warp(block.timestamp + 1 days);

        // Mock oracle calls with no price change
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
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1 ether, block.timestamp, block.timestamp, 0) // No price change
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("protocolFeeInfo(address)"),
            abi.encode(address(0), 0)
        );

        // Trigger interest accrual
        vm.prank(user);
        VaultFacet(facet).deposit(0, user);

        // Check that no fees were distributed
        assertEq(
            IERC20(facet).balanceOf(feeRecipient),
            0,
            "Should not distribute any fees when no price change"
        );
        assertEq(
            IERC20(facet).totalSupply(),
            depositAmount,
            "Should not mint extra shares for fee"
        );
    }
}

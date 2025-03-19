// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IVaultsFactory, VaultsFactory} from "../../src/factory/VaultsFactory.sol";
import {DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";
import {IDiamondCut} from "../../src/interfaces/facets/IDiamondCut.sol";
import {IMoreVaultsRegistry, IAaveOracle} from "../../src/interfaces/IMoreVaultsRegistry.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {VaultFacet} from "../../src/facets/VaultFacet.sol";

contract VaultsFactoryTest is Test {
    // Test addresses
    VaultsFactory public factory;
    address public registry;
    address public diamondCutFacet;
    address public admin = address(1);
    address public curator = address(2);
    address public guardian = address(3);
    address public feeRecipient = address(4);
    address public asset;

    // Test data
    string constant VAULT_NAME = "Test Vault";
    string constant VAULT_SYMBOL = "TV";
    uint96 constant FEE = 1000; // 10%
    uint256 constant TIME_LOCK_PERIOD = 1 days;

    function setUp() public {
        // Deploy mocks
        registry = address(1001);

        DiamondCutFacet cutFacet = new DiamondCutFacet();
        diamondCutFacet = address(cutFacet);

        MockERC20 mockAsset = new MockERC20("Test Asset", "TA");
        asset = address(mockAsset);

        // Deploy factory
        vm.prank(admin);
        factory = new VaultsFactory(registry, diamondCutFacet);
    }

    function test_constructor_ShouldSetInitialValues() public view {
        assertEq(
            address(VaultsFactory(factory).registry()),
            registry,
            "Should set correct registry"
        );
        assertEq(
            VaultsFactory(factory).diamondCutFacet(),
            diamondCutFacet,
            "Should set correct diamond cut facet"
        );
        assertTrue(
            VaultsFactory(factory).hasRole(0x00, admin),
            "Should set admin role"
        );
    }

    function test_setDiamondCutFacet_ShouldRevertWhenNotAdmin() public {
        address newFacet = address(5);
        vm.prank(curator);
        vm.expectRevert();
        VaultsFactory(factory).setDiamondCutFacet(newFacet);
    }

    function test_setDiamondCutFacet_ShouldRevertWithZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IVaultsFactory.ZeroAddress.selector);
        VaultsFactory(factory).setDiamondCutFacet(address(0));
    }

    function test_setDiamondCutFacet_ShouldUpdateFacet() public {
        address newFacet = address(5);
        vm.prank(admin);
        VaultsFactory(factory).setDiamondCutFacet(newFacet);
        assertEq(
            VaultsFactory(factory).diamondCutFacet(),
            newFacet,
            "Should update diamond cut facet"
        );
    }

    function test_deployVault_ShouldRevertWithZeroAddresses() public {
        IDiamondCut.FacetCut[] memory facets = new IDiamondCut.FacetCut[](0);

        vm.expectRevert(IVaultsFactory.ZeroAddress.selector);
        VaultsFactory(factory).deployVault(
            address(0), // zero asset address
            VAULT_NAME,
            VAULT_SYMBOL,
            curator,
            guardian,
            feeRecipient,
            FEE,
            TIME_LOCK_PERIOD,
            facets
        );

        vm.expectRevert(IVaultsFactory.ZeroAddress.selector);
        VaultsFactory(factory).deployVault(
            asset,
            VAULT_NAME,
            VAULT_SYMBOL,
            address(0), // zero curator address
            guardian,
            feeRecipient,
            FEE,
            TIME_LOCK_PERIOD,
            facets
        );
    }

    function test_deployVault_ShouldRevertWithInvalidTimeLock() public {
        IDiamondCut.FacetCut[] memory facets = new IDiamondCut.FacetCut[](0);

        vm.expectRevert(IVaultsFactory.InvalidTimeLock.selector);
        VaultsFactory(factory).deployVault(
            asset,
            VAULT_NAME,
            VAULT_SYMBOL,
            curator,
            guardian,
            feeRecipient,
            FEE,
            0, // zero time lock
            facets
        );
    }

    function test_deployVault_ShouldRevertWithInvalidFee() public {
        IDiamondCut.FacetCut[] memory facets = new IDiamondCut.FacetCut[](0);

        vm.expectRevert(IVaultsFactory.InvalidFee.selector);
        VaultsFactory(factory).deployVault(
            asset,
            VAULT_NAME,
            VAULT_SYMBOL,
            curator,
            guardian,
            feeRecipient,
            10001, // fee > 100%
            TIME_LOCK_PERIOD,
            facets
        );
    }

    function test_deployVault_ShouldDeployVaultWithFacets() public {
        // Prepare facets
        VaultFacet vaultFacet = new VaultFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VaultFacet.initialize.selector;

        IDiamondCut.FacetCut[] memory facets = new IDiamondCut.FacetCut[](1);
        facets[0] = IDiamondCut.FacetCut({
            facetAddress: address(vaultFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors,
            initData: ""
        });

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isFacetAllowed.selector,
                diamondCutFacet
            ),
            abi.encode(true)
        );

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.selectorToFacet.selector,
                IDiamondCut.diamondCut.selector
            ),
            abi.encode(diamondCutFacet)
        );

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.isFacetAllowed.selector,
                vaultFacet
            ),
            abi.encode(true)
        );

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.selectorToFacet.selector,
                selectors[0]
            ),
            abi.encode(vaultFacet)
        );

        address vault = VaultsFactory(factory).deployVault(
            asset,
            VAULT_NAME,
            VAULT_SYMBOL,
            curator,
            guardian,
            feeRecipient,
            FEE,
            TIME_LOCK_PERIOD,
            facets
        );

        assertTrue(
            VaultsFactory(factory).isVault(vault),
            "Should mark as factory vault"
        );
        assertEq(
            VaultsFactory(factory).getVaultsCount(),
            1,
            "Should increment vaults count"
        );

        address[] memory vaults = VaultsFactory(factory).getDeployedVaults();
        assertEq(vaults.length, 1, "Should have one deployed vault");
        assertEq(vaults[0], vault, "Should store deployed vault address");
    }

    function test_isVault_ShouldReturnFalseForNonFactoryVault() public view {
        assertFalse(
            VaultsFactory(factory).isVault(address(1)),
            "Should return false for non-factory vault"
        );
    }

    function test_getDeployedVaults_ShouldReturnEmptyArrayInitially()
        public
        view
    {
        address[] memory vaults = VaultsFactory(factory).getDeployedVaults();
        assertEq(vaults.length, 0, "Should return empty array initially");
    }

    function test_getVaultsCount_ShouldReturnZeroInitially() public view {
        assertEq(
            VaultsFactory(factory).getVaultsCount(),
            0,
            "Should return zero initially"
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IVaultsFactory, VaultsFactory} from "../../../src/factory/VaultsFactory.sol";
import {DiamondCutFacet} from "../../../src/facets/DiamondCutFacet.sol";
import {IAccessControlFacet, AccessControlFacet} from "../../../src/facets/AccessControlFacet.sol";
import {IDiamondCut} from "../../../src/interfaces/facets/IDiamondCut.sol";
import {IMoreVaultsRegistry, IOracleRegistry} from "../../../src/interfaces/IMoreVaultsRegistry.sol";
import {IAggregatorV2V3Interface} from "../../../src/interfaces/Chainlink/IAggregatorV2V3Interface.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";
import {VaultFacet} from "../../../src/facets/VaultFacet.sol";

contract VaultsFactoryTest is Test {
    // Test addresses
    VaultsFactory public factory;
    address public registry;
    address public diamondCutFacet;
    address public accessControlFacet;
    address public admin = address(1);
    address public curator = address(2);
    address public guardian = address(3);
    address public feeRecipient = address(4);
    address public oracle = address(5);
    address public asset;
    address public wrappedNative;

    // Test data
    string constant VAULT_NAME = "Test Vault";
    string constant VAULT_SYMBOL = "TV";
    uint96 constant FEE = 1000; // 10%
    uint256 constant TIME_LOCK_PERIOD = 1 days;

    function setUp() public {
        // Deploy mocks
        registry = address(1001);
        wrappedNative = address(1002);

        DiamondCutFacet cutFacet = new DiamondCutFacet();
        AccessControlFacet accessFacet = new AccessControlFacet();
        diamondCutFacet = address(cutFacet);
        accessControlFacet = address(accessFacet);

        MockERC20 mockAsset = new MockERC20("Test Asset", "TA");
        asset = address(mockAsset);

        // Deploy factory
        vm.prank(admin);
        factory = new VaultsFactory();
    }

    function test_initialize_ShouldSetInitialValues() public {
        vm.prank(admin);
        factory.initialize(
            registry,
            diamondCutFacet,
            accessControlFacet,
            wrappedNative
        );

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

    function test_initialize_ShouldRevertIfZeroAddress() public {
        vm.expectRevert(IVaultsFactory.ZeroAddress.selector);
        factory.initialize(
            address(0),
            diamondCutFacet,
            accessControlFacet,
            wrappedNative
        );

        vm.expectRevert(IVaultsFactory.ZeroAddress.selector);
        factory.initialize(
            registry,
            address(0),
            accessControlFacet,
            wrappedNative
        );

        vm.expectRevert(IVaultsFactory.ZeroAddress.selector);
        factory.initialize(
            registry,
            diamondCutFacet,
            address(0),
            wrappedNative
        );

        vm.expectRevert(IVaultsFactory.ZeroAddress.selector);
        factory.initialize(
            registry,
            diamondCutFacet,
            accessControlFacet,
            address(0)
        );
    }

    function test_setDiamondCutFacet_ShouldRevertWhenNotAdmin() public {
        vm.prank(admin);
        factory.initialize(
            registry,
            diamondCutFacet,
            accessControlFacet,
            wrappedNative
        );

        address newFacet = address(5);
        vm.prank(curator);
        vm.expectRevert();
        VaultsFactory(factory).setDiamondCutFacet(newFacet);
    }

    function test_setDiamondCutFacet_ShouldRevertWithZeroAddress() public {
        vm.prank(admin);
        factory.initialize(
            registry,
            diamondCutFacet,
            accessControlFacet,
            wrappedNative
        );

        vm.prank(admin);
        vm.expectRevert(IVaultsFactory.ZeroAddress.selector);
        VaultsFactory(factory).setDiamondCutFacet(address(0));
    }

    function test_setDiamondCutFacet_ShouldUpdateFacet() public {
        vm.prank(admin);
        factory.initialize(
            registry,
            diamondCutFacet,
            accessControlFacet,
            wrappedNative
        );

        address newFacet = address(5);
        vm.prank(admin);
        VaultsFactory(factory).setDiamondCutFacet(newFacet);
        assertEq(
            VaultsFactory(factory).diamondCutFacet(),
            newFacet,
            "Should update diamond cut facet"
        );
    }

    function test_setAccessControlFacet_ShouldRevertWhenNotAdmin() public {
        vm.prank(admin);
        factory.initialize(
            registry,
            diamondCutFacet,
            accessControlFacet,
            wrappedNative
        );

        address newFacet = address(5);
        vm.prank(curator);
        vm.expectRevert();
        VaultsFactory(factory).setAccessControlFacet(newFacet);
    }

    function test_setAccessControlFacet_ShouldRevertWithZeroAddress() public {
        vm.prank(admin);
        factory.initialize(
            registry,
            diamondCutFacet,
            accessControlFacet,
            wrappedNative
        );

        vm.prank(admin);
        vm.expectRevert(IVaultsFactory.ZeroAddress.selector);
        VaultsFactory(factory).setAccessControlFacet(address(0));
    }

    function test_setAccessControlFacet_ShouldUpdateFacet() public {
        vm.prank(admin);
        factory.initialize(
            registry,
            diamondCutFacet,
            accessControlFacet,
            wrappedNative
        );

        address newFacet = address(5);
        vm.prank(admin);
        VaultsFactory(factory).setAccessControlFacet(newFacet);
        assertEq(
            VaultsFactory(factory).accessControlFacet(),
            newFacet,
            "Should update access control facet"
        );
    }

    function test_deployVault_ShouldDeployVaultWithFacets() public {
        vm.prank(admin);
        factory.initialize(
            registry,
            diamondCutFacet,
            accessControlFacet,
            wrappedNative
        );

        // Prepare facets
        VaultFacet vaultFacet = new VaultFacet();
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VaultFacet.initialize.selector;

        IDiamondCut.FacetCut[] memory facets = new IDiamondCut.FacetCut[](1);
        facets[0] = IDiamondCut.FacetCut({
            facetAddress: address(vaultFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors,
            initData: abi.encode(
                VAULT_NAME,
                VAULT_SYMBOL,
                asset,
                feeRecipient,
                FEE
            )
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
                accessControlFacet
            ),
            abi.encode(true)
        );

        vm.mockCall(
            registry,
            abi.encodeWithSelector(
                IMoreVaultsRegistry.selectorToFacet.selector,
                IAccessControlFacet.setMoreVaultsRegistry.selector
            ),
            abi.encode(accessControlFacet)
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

        vm.mockCall(
            address(registry),
            abi.encodeWithSelector(IMoreVaultsRegistry.oracle.selector),
            abi.encode(oracle)
        );

        // IOracleRegistry.AssetSource memory assetSource = IOracleRegistry
        //     .AssetSource({
        //         aggregator: IAggregatorV2V3Interface(asset),
        //         stalenessThreshold: 1000
        //     });
        vm.mockCall(
            oracle,
            abi.encodeWithSelector(
                IOracleRegistry.getOracleInfo.selector,
                asset
            ),
            abi.encode(address(1000), uint96(1000))
        );

        bytes memory accessControlFacetInitData = abi.encode(
            admin,
            curator,
            guardian
        );
        address vault = VaultsFactory(factory).deployVault(
            facets,
            accessControlFacetInitData
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
        assertEq(
            VaultsFactory(factory).isVault(vault),
            true,
            "Should be a factory vault"
        );
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

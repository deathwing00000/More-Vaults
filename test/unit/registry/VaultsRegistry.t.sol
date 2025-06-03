// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IMoreVaultsRegistry, VaultsRegistry} from "../../../src/registry/VaultsRegistry.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";

contract VaultsRegistryTest is Test {
    VaultsRegistry public registry;
    MockERC20 public usdc;
    address public admin = address(1);
    address public user = address(2);
    address public vault = address(3);
    address public recipient = address(4);
    address public facet = address(5);
    address public oracle = address(6);
    address public baseCurrency = address(7);

    function setUp() public {
        // Deploy mocks
        usdc = new MockERC20("USD Coin", "USDC");

        // Deploy registry
        vm.prank(admin);
        registry = new VaultsRegistry();
        vm.prank(admin);
        registry.initialize(address(oracle), address(usdc));

        // Mock oracle calls
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("BASE_CURRENCY()"),
            abi.encode(baseCurrency)
        );
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("getSourceOfAsset(address)"),
            abi.encode(address(0))
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

    function test_addFacet_ShouldAddFacetAndSelectors() public {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256("test1()"));
        selectors[1] = bytes4(keccak256("test2()"));

        vm.prank(admin);
        registry.addFacet(facet, selectors);

        assertTrue(registry.isFacetAllowed(facet), "Should allow facet");
        assertEq(
            registry.getFacetSelectors(facet).length,
            2,
            "Should add selectors"
        );
        assertEq(
            registry.selectorToFacet(selectors[0]),
            facet,
            "Should map selector to facet"
        );
        assertEq(
            registry.selectorToFacet(selectors[1]),
            facet,
            "Should map selector to facet"
        );
    }

    function test_addFacet_ShouldAddSelectorsIfFacetAlreadyExists() public {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256("test1()"));
        selectors[1] = bytes4(keccak256("test2()"));

        vm.prank(admin);
        registry.addFacet(facet, selectors);

        bytes4[] memory selectorsNew = new bytes4[](1);
        selectorsNew[0] = bytes4(keccak256("test3()"));

        vm.prank(admin);
        registry.addFacet(facet, selectorsNew);
        assertTrue(registry.isFacetAllowed(facet), "Should allow facet");
        assertEq(
            registry.getFacetSelectors(facet).length,
            3,
            "Should add selectors"
        );
        assertEq(
            registry.selectorToFacet(selectors[0]),
            facet,
            "Should map selector to facet"
        );
        assertEq(
            registry.selectorToFacet(selectors[1]),
            facet,
            "Should map selector to facet"
        );
        assertEq(
            registry.selectorToFacet(selectorsNew[0]),
            facet,
            "Should map selector to facet"
        );
    }

    function test_addFacet_ShouldRevertWithZeroAddress() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("test()"));

        vm.prank(admin);
        vm.expectRevert(IMoreVaultsRegistry.ZeroAddress.selector);
        registry.addFacet(address(0), selectors);
    }

    function test_addFacet_ShouldRevertWhenSelectorAlreadyExists() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("test()"));

        vm.prank(admin);
        registry.addFacet(facet, selectors);

        address facet2 = address(6);
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMoreVaultsRegistry.SelectorAlreadyExists.selector,
                facet,
                selectors[0]
            )
        );
        registry.addFacet(facet2, selectors);
    }

    function test_removeFacet_ShouldRemoveFacetAndSelectors() public {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256("test1()"));
        selectors[1] = bytes4(keccak256("test2()"));

        vm.prank(admin);
        registry.addFacet(facet, selectors);

        vm.prank(admin);
        registry.removeFacet(facet);

        assertFalse(registry.isFacetAllowed(facet), "Should not allow facet");
        assertEq(
            registry.getFacetSelectors(facet).length,
            0,
            "Should remove selectors"
        );
        assertEq(
            registry.selectorToFacet(selectors[0]),
            address(0),
            "Should remove selector mapping"
        );
        assertEq(
            registry.selectorToFacet(selectors[1]),
            address(0),
            "Should remove selector mapping"
        );
    }

    function test_removeFacet_ShouldRevertWhenFacetNotAllowed() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMoreVaultsRegistry.FacetNotAllowed.selector,
                facet
            )
        );
        registry.removeFacet(facet);
    }

    function test_setProtocolFeeInfo_ShouldSetFeeInfo() public {
        uint96 fee = 1000; // 10%

        vm.prank(admin);
        registry.setProtocolFeeInfo(vault, recipient, fee);

        (address feeRecipient, uint96 actualFee) = registry.protocolFeeInfo(
            vault
        );
        assertEq(feeRecipient, recipient, "Should set correct recipient");
        assertEq(actualFee, fee, "Should set correct fee");
    }

    function test_setProtocolFeeInfo_ShouldRevertWithZeroRecipient() public {
        vm.prank(admin);
        vm.expectRevert(IMoreVaultsRegistry.ZeroAddress.selector);
        registry.setProtocolFeeInfo(vault, address(0), 1000);
    }

    function test_setProtocolFeeInfo_ShouldRevertWithInvalidFee() public {
        vm.prank(admin);
        vm.expectRevert(VaultsRegistry.InvalidFee.selector);
        registry.setProtocolFeeInfo(vault, recipient, 5001); // 50.01%
    }

    function test_setProtocolFeeInfo_ShouldRevertWhenNotAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        registry.setProtocolFeeInfo(vault, recipient, 1000);
    }

    function test_isFacetAllowed_ShouldReturnCorrectValue() public {
        assertFalse(
            registry.isFacetAllowed(facet),
            "Should not allow unknown facet"
        );

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("test()"));

        vm.prank(admin);
        registry.addFacet(facet, selectors);

        assertTrue(registry.isFacetAllowed(facet), "Should allow added facet");
    }

    function test_getDenominationAsset_ShouldReturnBaseCurrency() public view {
        assertEq(
            registry.getDenominationAsset(),
            baseCurrency,
            "Should return base currency"
        );
    }

    function test_getDenominationAsset_ShouldReturnUsdcWhenNoBaseCurrency()
        public
    {
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("BASE_CURRENCY()"),
            abi.encode(address(0))
        );

        assertEq(
            registry.getDenominationAsset(),
            address(usdc),
            "Should return USDC address"
        );
    }

    function test_getDenominationAssetDecimals_ShouldReturnBaseCurrencyDecimals()
        public
    {
        vm.mockCall(
            baseCurrency,
            abi.encodeWithSignature("decimals()"),
            abi.encode(8)
        );
        assertEq(
            registry.getDenominationAssetDecimals(),
            8,
            "Should return base currency decimals"
        );
    }

    function test_getDenominationAssetDecimals_ShouldReturnUsdcDecimalsWhenNoBaseCurrency()
        public
    {
        vm.mockCall(
            oracle,
            abi.encodeWithSignature("BASE_CURRENCY()"),
            abi.encode(address(0))
        );

        assertEq(
            registry.getDenominationAssetDecimals(),
            MockERC20(address(usdc)).decimals(),
            "Should return USDC decimals"
        );
    }

    function test_getAllowedFacets_ShouldReturnAllFacets() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("test()"));

        vm.prank(admin);
        registry.addFacet(facet, selectors);

        address[] memory facets = registry.getAllowedFacets();
        assertEq(facets.length, 1, "Should return all facets");
        assertEq(facets[0], facet, "Should return correct facet");
    }

    function test_removeFacet_ShouldFindFacetAndRemoveIt() public {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256("test()"));
        selectors[1] = bytes4(keccak256("test2()"));

        address facet2 = address(6);
        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = bytes4(keccak256("test3()"));

        vm.startPrank(admin);
        registry.addFacet(facet, selectors);
        registry.addFacet(facet2, selectors2);

        registry.removeFacet(facet2);

        assertEq(registry.getAllowedFacets().length, 1, "Should remove facet");
        assertEq(
            registry.getAllowedFacets()[0],
            facet,
            "Should return correct facet"
        );
        vm.stopPrank();
    }

    function test_addToWhitelist_ShouldWhitelistProtocol() public {
        assertFalse(
            registry.isWhitelisted(vault),
            "Should not be whitelisted by default"
        );

        vm.prank(admin);
        registry.addToWhitelist(vault);

        assertTrue(
            registry.isWhitelisted(vault),
            "Should be whitelisted after add"
        );
    }

    function test_removeFromWhitelist_ShouldRemoveProtocolFromWhitelist()
        public
    {
        vm.prank(admin);
        registry.addToWhitelist(vault);
        assertTrue(
            registry.isWhitelisted(vault),
            "Should be whitelisted after add"
        );

        vm.prank(admin);
        registry.removeFromWhitelist(vault);

        assertFalse(
            registry.isWhitelisted(vault),
            "Should not be whitelisted after remove"
        );
    }

    function test_addToWhitelist_ShouldRevertWhenNotAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        registry.addToWhitelist(vault);
    }

    function test_removeFromWhitelist_ShouldRevertWhenNotAdmin() public {
        vm.prank(admin);
        registry.addToWhitelist(vault);

        vm.prank(user);
        vm.expectRevert();
        registry.removeFromWhitelist(vault);
    }

    function test_isWhitelisted_ShouldReturnCorrectValue() public {
        assertEq(
            registry.isWhitelisted(address(1)),
            false,
            "Should not be whitelisted by default"
        );
        vm.prank(admin);
        registry.addToWhitelist(address(1));
        assertTrue(registry.isWhitelisted(address(1)), "Should be whitelisted");

        vm.prank(admin);
        registry.removeFromWhitelist(address(1));
        assertFalse(
            registry.isWhitelisted(address(1)),
            "Should not be whitelisted after remove"
        );
    }
}

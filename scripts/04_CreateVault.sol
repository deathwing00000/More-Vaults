// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DeployUtils} from "./utils/DeployUtils.sol";
import {VaultsFactory} from "../src/VaultsFactory.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";

contract CreateVault is Script, DeployUtils {
    function run() external {
        uint256 deployerPrivateKey = readPrivateKey();

        // Read factory address
        address factory = vm.envAddress("VAULTS_FACTORY");

        // Prepare vault parameters
        address asset = address(0x123); // token address
        string memory name = "My Vault";
        string memory symbol = "MVLT";
        address curator = address(0x456);
        address guardian = address(0x789);
        address feeRecipient = address(0xabc);
        uint96 fee = 100; // 1%
        uint256 timeLockPeriod = 1 days;
        address defaultSwapRouter = address(0xdef);

        // Prepare facetCuts
        IDiamondCut.FacetCut[] memory facetCuts = prepareFacetCuts();

        vm.startBroadcast(deployerPrivateKey);

        // Create vault
        address vault = VaultsFactory(factory).deployVault(
            asset,
            name,
            symbol,
            curator,
            guardian,
            feeRecipient,
            fee,
            timeLockPeriod,
            defaultSwapRouter,
            facetCuts
        );

        console2.log("Vault deployed at:", vault);

        vm.stopBroadcast();
    }

    function prepareFacetCuts()
        internal
        view
        returns (IDiamondCut.FacetCut[] memory)
    {
        // Read facet addresses
        address diamondLoupeFacet = vm.envAddress("DIAMOND_LOUPE_FACET");
        address accessControlFacet = vm.envAddress("ACCESS_CONTROL_FACET");
        address configurationFacet = vm.envAddress("CONFIGURATION_FACET");

        // Create facetCuts array with necessary facets and their selectors
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](3);

        // Fill cuts array...
        // Note: This needs to be completed with actual selectors for each facet

        return cuts;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DeployUtils} from "./utils/DeployUtils.sol";
import {VaultsFactory} from "../src/VaultsFactory.sol";

contract DeployFactory is Script, DeployUtils {
    function run() external {
        uint256 deployerPrivateKey = readPrivateKey();

        // Read required addresses
        address registry = vm.envAddress("VAULT_REGISTRY");
        address diamondCutFacet = vm.envAddress("DIAMOND_CUT_FACET");
        address diamondInit = vm.envAddress("DIAMOND_INIT"); // need to add to previous scripts

        vm.startBroadcast(deployerPrivateKey);

        // Deploy factory
        VaultsFactory factory = new VaultsFactory(
            registry,
            diamondCutFacet,
            diamondInit
        );
        console2.log("VaultsFactory deployed at:", address(factory));

        vm.stopBroadcast();

        // Save factory address
        vm.writeFile(
            ".env.deployments",
            string(
                abi.encodePacked(
                    vm.readFile(".env.deployments"),
                    "VAULTS_FACTORY=",
                    vm.toString(address(factory)),
                    "\n"
                )
            )
        );
    }
}

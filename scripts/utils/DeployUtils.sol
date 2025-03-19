// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

abstract contract DeployUtils is Script {
    function readPrivateKey() internal view returns (uint256) {
        try vm.envUint("PRIVATE_KEY") returns (uint256 privateKey) {
            return privateKey;
        } catch {
            revert("PRIVATE_KEY environment variable not set");
        }
    }

    function verifyContract(address deployment, bytes memory args) internal {
        if (block.chainid != 31337) {
            string[] memory commands = new string[](5);
            commands[0] = "forge";
            commands[1] = "verify-contract";
            commands[2] = vm.toString(deployment);
            commands[3] = "--constructor-args";
            commands[4] = vm.toString(args);

            vm.ffi(commands);
        }
    }
}

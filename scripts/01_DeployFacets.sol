// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {DeployUtils} from "./utils/DeployUtils.sol";
import {DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/facets/DiamondLoupeFacet.sol";
import {AccessControlFacet} from "../src/facets/AccessControlFacet.sol";
import {ConfigurationFacet} from "../src/facets/ConfigurationFacet.sol";
import {OrigamiFacet} from "../src/facets/OrigamiFacet.sol";
import {MoreMarketsFacet} from "../src/facets/MoreMarketsFacet.sol";
import {VaultFacet} from "../src/facets/VaultFacet.sol";
import {MulticallFacet} from "../src/facets/MulticallFacet.sol";
import {UniswapV2Facet} from "../src/facets/UniswapV2Facet.sol";
import {IzumiSwapFacet} from "../src/facets/IzumiSwapFacet.sol";

contract DeployFacets is Script, DeployUtils {
    function run() external {
        uint256 deployerPrivateKey = readPrivateKey();

        // Deploy all facets sequentially
        vm.startBroadcast(deployerPrivateKey);

        // 1. DiamondCutFacet
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        console2.log("DiamondCutFacet deployed at:", address(diamondCutFacet));

        // 2. DiamondLoupeFacet
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        console2.log(
            "DiamondLoupeFacet deployed at:",
            address(diamondLoupeFacet)
        );

        // 3. AccessControlFacet
        AccessControlFacet accessControlFacet = new AccessControlFacet();
        console2.log(
            "AccessControlFacet deployed at:",
            address(accessControlFacet)
        );

        // 4. ConfigurationFacet
        ConfigurationFacet configurationFacet = new ConfigurationFacet();
        console2.log(
            "ConfigurationFacet deployed at:",
            address(configurationFacet)
        );

        // 5. VaultFacet
        VaultFacet vaultFacet = new VaultFacet();
        console2.log("VaultFacet deployed at:", address(vaultFacet));

        // 6. MulticallFacet
        MulticallFacet multicallFacet = new MulticallFacet();
        console2.log("MulticallFacet deployed at:", address(multicallFacet));

        // 7. UniswapV2Facet
        UniswapV2Facet uniswapV2Facet = new UniswapV2Facet();
        console2.log("UniswapV2Facet deployed at:", address(uniswapV2Facet));

        // 8. IzumiSwapFacet
        IzumiSwapFacet izumiSwapFacet = new IzumiSwapFacet();
        console2.log("IzumiSwapFacet deployed at:", address(izumiSwapFacet));

        // 9. OrigamiFacet
        OrigamiFacet origamiFacet = new OrigamiFacet();
        console2.log("OrigamiFacet deployed at:", address(origamiFacet));

        // 10. MoreMarketsFacet
        MoreMarketsFacet moreMarketsFacet = new MoreMarketsFacet();
        console2.log(
            "MoreMarketsFacet deployed at:",
            address(moreMarketsFacet)
        );

        vm.stopBroadcast();

        // Save addresses to .env file
        string memory addresses = string(
            abi.encodePacked(
                "DIAMOND_CUT_FACET=",
                vm.toString(address(diamondCutFacet)),
                "\n",
                "DIAMOND_LOUPE_FACET=",
                vm.toString(address(diamondLoupeFacet)),
                "\n",
                "ACCESS_CONTROL_FACET=",
                vm.toString(address(accessControlFacet)),
                "\n",
                "CONFIGURATION_FACET=",
                vm.toString(address(configurationFacet)),
                "\n",
                "VAULT_FACET=",
                vm.toString(address(vaultFacet)),
                "\n",
                "MULTICALL_FACET=",
                vm.toString(address(multicallFacet)),
                "\n",
                "UNISWAP_V2_FACET=",
                vm.toString(address(uniswapV2Facet)),
                "\n",
                "IZUMI_SWAP_FACET=",
                vm.toString(address(izumiSwapFacet)),
                "\n",
                "ORIGAMI_FACET=",
                vm.toString(address(origamiFacet)),
                "\n",
                "MORE_MARKETS_FACET=",
                vm.toString(address(moreMarketsFacet)),
                "\n"
            )
        );
        vm.writeFile(".env.deployments", addresses);

        // Also log addresses for verification
        console2.log("\n=== Deployed Facet Addresses ===");
        console2.log("DIAMOND_CUT_FACET=", address(diamondCutFacet));
        console2.log("DIAMOND_LOUPE_FACET=", address(diamondLoupeFacet));
        console2.log("ACCESS_CONTROL_FACET=", address(accessControlFacet));
        console2.log("CONFIGURATION_FACET=", address(configurationFacet));
        console2.log("VAULT_FACET=", address(vaultFacet));
        console2.log("MULTICALL_FACET=", address(multicallFacet));
        console2.log("UNISWAP_V2_FACET=", address(uniswapV2Facet));
        console2.log("IZUMI_SWAP_FACET=", address(izumiSwapFacet));
        console2.log("ORIGAMI_FACET=", address(origamiFacet));
        console2.log("MORE_MARKETS_FACET=", address(moreMarketsFacet));
        console2.log("==============================\n");
    }
}

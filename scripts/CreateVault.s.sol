// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {VaultsRegistry} from "../src/registry/VaultsRegistry.sol";
import {VaultsFactory} from "../src/factory/VaultsFactory.sol";
import {MoreVaultsDiamond} from "../src/MoreVaultsDiamond.sol";
import {IDiamondCut, DiamondCutFacet} from "../src/facets/DiamondCutFacet.sol";
import {IERC165, IDiamondLoupe, DiamondLoupeFacet} from "../src/facets/DiamondLoupeFacet.sol";
import {IAccessControlFacet, AccessControlFacet} from "../src/facets/AccessControlFacet.sol";
import {IConfigurationFacet, ConfigurationFacet} from "../src/facets/ConfigurationFacet.sol";
import {IMulticallFacet, MulticallFacet} from "../src/facets/MulticallFacet.sol";
import {IVaultFacet, IERC4626, IERC20, VaultFacet} from "../src/facets/VaultFacet.sol";
import {IUniswapV2Facet, UniswapV2Facet} from "../src/facets/UniswapV2Facet.sol";
import {IOrigamiFacet, OrigamiFacet} from "../src/facets/OrigamiFacet.sol";
import {IPool, IMoreMarketsFacet, MoreMarketsFacet} from "../src/facets/MoreMarketsFacet.sol";
import {IIzumiSwapFacet, IzumiSwapFacet} from "../src/facets/IzumiSwapFacet.sol";
import {IAggroKittySwapFacet, AggroKittySwapFacet} from "../src/facets/AggroKittySwapFacet.sol";
import {DeployConfig} from "./config/DeployConfig.s.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {console} from "forge-std/console.sol";

// testnet deployment script
// forge script scripts/CreateVault.s.sol:CreateVaultScript --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org -vv --slow --broadcast --verify --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api/'

// mainnet deployment script
// forge script scripts/CreateVault.s.sol:CreateVaultScript --chain-id 747 --rpc-url https://mainnet.evm.nodes.onflow.org -vv --slow --broadcast --verify --verifier blockscout --verifier-url 'https://evm.flowscan.io/api/'

contract CreateVaultScript is Script {
    DeployConfig config;
    VaultsFactory factory;

    address diamondLoupe;
    address accessControl;
    address configuration;
    address multicall;
    address uniswapV2;
    address origami;
    address moreMarkets;
    address izumiSwap;
    address aggroKittySwap;
    address curve;
    address vault;
    address uniswapV3;
    address multiRewards;
    address curveGaugeV6;

    function test_skip() public pure {}

    function setUp() public {
        // Load config from environment variables
        config = new DeployConfig();

        config.initParamsForVaultCreation(
            vm.envAddress("OWNER"),
            vm.envAddress("CURATOR"),
            vm.envAddress("GUARDIAN"),
            vm.envAddress("FEE_RECIPIENT"),
            vm.envAddress("UNDERLYING_ASSET"),
            uint96(vm.envUint("FEE")),
            vm.envUint("DEPOSIT_CAPACITY"),
            vm.envUint("TIME_LOCK_PERIOD")
        );

        diamondLoupe = vm.envAddress("DIAMOND_LOUPE_FACET");
        accessControl = vm.envAddress("ACCESS_CONTROL_FACET");
        configuration = vm.envAddress("CONFIGURATION_FACET");
        vault = vm.envAddress("VAULT_FACET");
        multicall = vm.envAddress("MULTICALL_FACET");
        uniswapV2 = vm.envAddress("UNISWAP_V2_FACET");
        origami = vm.envAddress("ORIGAMI_FACET");
        moreMarkets = vm.envAddress("MORE_MARKETS_FACET");
        izumiSwap = vm.envAddress("IZUMI_SWAP_FACET");
        aggroKittySwap = vm.envAddress("AGGRO_KITTY_SWAP_FACET");
        curve = vm.envAddress("CURVE_FACET");
        uniswapV3 = vm.envAddress("UNISWAP_V3_FACET");
        multiRewards = vm.envAddress("MULTI_REWARDS_FACET");
        curveGaugeV6 = vm.envAddress("CURVE_LIQUIDITY_GAUGE_V6_FACET");
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        factory = VaultsFactory(vm.envAddress("VAULTS_FACTORY"));

        DeployConfig.FacetAddresses memory facetAddresses;
        facetAddresses.diamondLoupe = address(diamondLoupe);
        facetAddresses.accessControl = address(accessControl);
        facetAddresses.configuration = address(configuration);
        facetAddresses.multicall = address(multicall);
        facetAddresses.vault = address(vault);
        facetAddresses.uniswapV2 = address(uniswapV2);
        facetAddresses.origami = address(origami);
        facetAddresses.moreMarkets = address(moreMarkets);
        facetAddresses.izumiSwap = address(izumiSwap);
        facetAddresses.aggroKittySwap = address(aggroKittySwap);
        facetAddresses.curve = address(curve);
        facetAddresses.uniswapV3 = address(uniswapV3);
        facetAddresses.multiRewards = address(multiRewards);
        facetAddresses.curveGaugeV6 = address(curveGaugeV6);

        IDiamondCut.FacetCut[] memory cuts = config.getCuts(facetAddresses);

        // Deploy vault
        address vaultAddress = factory.deployVault(cuts);
        console.log("Vault deployed at:", vaultAddress);

        // Save factory address
        vm.writeFile(
            ".env.deployments",
            string(
                abi.encodePacked(
                    vm.readFile(".env.deployments"),
                    "VAULT_ADDRESS=",
                    vm.toString(vaultAddress),
                    "\n"
                )
            )
        );

        vm.stopBroadcast();
    }
}

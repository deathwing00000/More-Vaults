// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {VaultsRegistry} from "../src/registry/VaultsRegistry.sol";
import {BaseVaultsRegistry} from "../src/registry/BaseVaultsRegistry.sol";
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
import {console} from "forge-std/console.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {CurveFacet} from "../src/facets/CurveFacet.sol";

// forge script scripts/Deploy.s.sol:DeployScript --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api/'

contract DeployScript is Script {
    DeployConfig config;
    VaultsRegistry registry;
    VaultsFactory factory;
    MoreVaultsDiamond diamond;
    DiamondCutFacet diamondCut;
    DiamondLoupeFacet diamondLoupe;
    AccessControlFacet accessControl;
    ConfigurationFacet configuration;
    MulticallFacet multicall;
    VaultFacet vault;
    UniswapV2Facet uniswapV2;
    OrigamiFacet origami;
    MoreMarketsFacet moreMarkets;
    IzumiSwapFacet izumiSwap;
    AggroKittySwapFacet aggroKittySwap;
    CurveFacet curve;

    function test_skip() public pure {}

    function setUp() public {
        // Load config from environment variables
        config = new DeployConfig(
            vm.envAddress("OWNER"),
            vm.envAddress("CURATOR"),
            vm.envAddress("GUARDIAN"),
            vm.envAddress("FEE_RECIPIENT"),
            vm.envAddress("TREASURY"),
            vm.envAddress("WRAPPED_NATIVE"),
            vm.envAddress("ASSET_TO_DEPOSIT"),
            vm.envAddress("USDCE"),
            vm.envAddress("AAVE_ORACLE"),
            uint96(vm.envUint("FEE")),
            vm.envUint("DEPOSIT_CAPACITY"),
            vm.envUint("TIME_LOCK_PERIOD")
        );
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy facets
        diamondCut = new DiamondCutFacet();
        diamondLoupe = new DiamondLoupeFacet();
        accessControl = new AccessControlFacet();
        configuration = new ConfigurationFacet();
        multicall = new MulticallFacet();
        vault = new VaultFacet();
        uniswapV2 = new UniswapV2Facet();
        origami = new OrigamiFacet();
        moreMarkets = new MoreMarketsFacet();
        izumiSwap = new IzumiSwapFacet();
        aggroKittySwap = new AggroKittySwapFacet();
        curve = new CurveFacet();

        // Save addresses to .env file
        string memory addresses = string(
            abi.encodePacked(
                "DIAMOND_CUT_FACET=",
                vm.toString(address(diamondCut)),
                "\n",
                "DIAMOND_LOUPE_FACET=",
                vm.toString(address(diamondLoupe)),
                "\n",
                "ACCESS_CONTROL_FACET=",
                vm.toString(address(accessControl)),
                "\n",
                "CONFIGURATION_FACET=",
                vm.toString(address(configuration)),
                "\n",
                "VAULT_FACET=",
                vm.toString(address(vault)),
                "\n",
                "MULTICALL_FACET=",
                vm.toString(address(multicall)),
                "\n",
                "UNISWAP_V2_FACET=",
                vm.toString(address(uniswapV2)),
                "\n",
                "IZUMI_SWAP_FACET=",
                vm.toString(address(izumiSwap)),
                "\n",
                "ORIGAMI_FACET=",
                vm.toString(address(origami)),
                "\n",
                "MORE_MARKETS_FACET=",
                vm.toString(address(moreMarkets)),
                "\n",
                "AGGRO_KITTY_SWAP_FACET=",
                vm.toString(address(aggroKittySwap)),
                "\n",
                "CURVE_FACET=",
                vm.toString(address(curve)),
                "\n"
            )
        );
        vm.writeFile(".env", addresses);

        console.log("Facets deployed");

        // Deploy registry
        address registryImplementation = address(new VaultsRegistry());
        registry = VaultsRegistry(
            address(
                new TransparentUpgradeableProxy(
                    registryImplementation,
                    msg.sender,
                    abi.encodeWithSelector(
                        BaseVaultsRegistry.initialize.selector,
                        config.aaveOracle(),
                        config.usdce()
                    )
                )
            )
        );
        console.log("Registry deployed at:", address(registry));

        // Save registry address
        vm.writeFile(
            ".env.deployments",
            string(
                abi.encodePacked(
                    vm.readFile(".env.deployments"),
                    "VAULT_REGISTRY=",
                    vm.toString(address(registry)),
                    "\n"
                )
            )
        );

        // Add diamond cut facet to registry
        bytes4[] memory functionSelectorsDiamondCutFacet = new bytes4[](1);
        functionSelectorsDiamondCutFacet[0] = IDiamondCut.diamondCut.selector;
        registry.addFacet(
            address(diamondCut),
            functionSelectorsDiamondCutFacet
        );

        // Add facets to registry
        IDiamondCut.FacetCut[] memory cuts = config.getCuts(
            address(diamondLoupe),
            address(accessControl),
            address(configuration),
            address(multicall),
            address(vault),
            address(uniswapV2),
            address(origami),
            address(moreMarkets),
            address(izumiSwap),
            address(aggroKittySwap),
            address(curve)
        );
        for (uint i = 0; i < cuts.length; ) {
            registry.addFacet(cuts[i].facetAddress, cuts[i].functionSelectors);
            unchecked {
                ++i;
            }
        }
        console.log("Facets added to registry");

        // Deploy factory
        address factoryImplementation = address(new VaultsFactory());
        factory = VaultsFactory(
            address(
                new TransparentUpgradeableProxy(
                    factoryImplementation,
                    msg.sender,
                    abi.encodeWithSelector(
                        VaultsFactory.initialize.selector,
                        address(registry),
                        address(diamondCut),
                        config.wrappedNative()
                    )
                )
            )
        );
        console.log("Factory deployed at:", address(factory));

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

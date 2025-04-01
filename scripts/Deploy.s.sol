// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
import {console} from "forge-std/console.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

// forge script script/Deploy.s.sol:DeployScript --chain-id 545 --rpc-url https://testnet.evm.nodes.onflow.org --broadcast -vv --verify --slow --verifier blockscout --verifier-url 'https://evm-testnet.flowscan.io/api/'

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

    function test_skip() public pure {}

    function setUp() public {
        // Load config from environment variables
        config = new DeployConfig(
            vm.envAddress("CURATOR"),
            vm.envAddress("GUARDIAN"),
            vm.envAddress("FEE_RECIPIENT"),
            vm.envAddress("TREASURY"),
            vm.envAddress("WRAPPED_NATIVE"),
            vm.envAddress("USDCE"),
            vm.envAddress("AAVE_ORACLE")
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
                "\n"
            )
        );
        vm.writeFile(".env.deployments", addresses);

        console.log("Facets deployed");

        // Deploy registry
        registry = new VaultsRegistry(config.aaveOracle(), config.usdce());
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
        IDiamondCut.FacetCut[] memory cuts = _getCuts();
        for (uint i = 0; i < cuts.length; ) {
            registry.addFacet(cuts[i].facetAddress, cuts[i].functionSelectors);
            unchecked {
                ++i;
            }
        }
        console.log("Facets added to registry");

        // Deploy factory
        factory = new VaultsFactory();
        factory.initialize(
            address(registry),
            address(diamondCut),
            config.wrappedNative()
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

    function _getCuts() internal view returns (IDiamondCut.FacetCut[] memory) {
        // selectors for diamond loupe
        bytes4[] memory functionSelectorsLoupeFacet = new bytes4[](5);
        functionSelectorsLoupeFacet[0] = IDiamondLoupe.facets.selector;
        functionSelectorsLoupeFacet[1] = IDiamondLoupe
            .facetFunctionSelectors
            .selector;
        functionSelectorsLoupeFacet[2] = IDiamondLoupe.facetAddresses.selector;
        functionSelectorsLoupeFacet[3] = IDiamondLoupe.facetAddress.selector;
        functionSelectorsLoupeFacet[4] = IERC165.supportsInterface.selector;

        // selectors for access control
        bytes4[] memory functionSelectorsAccessControlFacet = new bytes4[](6);
        functionSelectorsAccessControlFacet[0] = AccessControlFacet
            .setMoreVaultRegistry
            .selector;
        functionSelectorsAccessControlFacet[1] = AccessControlFacet
            .transferCuratorship
            .selector;
        functionSelectorsAccessControlFacet[2] = AccessControlFacet
            .transferGuardian
            .selector;
        functionSelectorsAccessControlFacet[3] = AccessControlFacet
            .curator
            .selector;
        functionSelectorsAccessControlFacet[4] = AccessControlFacet
            .guardian
            .selector;
        functionSelectorsAccessControlFacet[5] = AccessControlFacet
            .moreVaultsRegistry
            .selector;

        bytes memory initDataAccessControlFacet = abi.encode(
            config.curator(),
            config.guardian(),
            address(registry)
        );

        // selectors for configuration
        bytes4[] memory functionSelectorsConfigurationFacet = new bytes4[](7);
        functionSelectorsConfigurationFacet[0] = ConfigurationFacet
            .setFeeRecipient
            .selector;
        functionSelectorsConfigurationFacet[1] = ConfigurationFacet
            .setFee
            .selector;
        functionSelectorsConfigurationFacet[2] = ConfigurationFacet
            .setTimeLockPeriod
            .selector;
        functionSelectorsConfigurationFacet[3] = ConfigurationFacet
            .addAvailableAsset
            .selector;
        functionSelectorsConfigurationFacet[4] = ConfigurationFacet
            .addAvailableAssets
            .selector;
        functionSelectorsConfigurationFacet[5] = ConfigurationFacet
            .isAssetAvailable
            .selector;
        functionSelectorsConfigurationFacet[6] = ConfigurationFacet
            .getAvailableAssets
            .selector;

        // selectors for multicall
        bytes4[] memory functionSelectorsMulticallFacet = new bytes4[](5);
        functionSelectorsMulticallFacet[0] = MulticallFacet
            .submitActions
            .selector;
        functionSelectorsMulticallFacet[1] = MulticallFacet
            .executeActions
            .selector;
        functionSelectorsMulticallFacet[2] = MulticallFacet
            .vetoActions
            .selector;
        functionSelectorsMulticallFacet[3] = MulticallFacet
            .getPendingActions
            .selector;
        functionSelectorsMulticallFacet[4] = MulticallFacet
            .getCurrentNonce
            .selector;
        bytes memory initDataMulticallFacet = abi.encode(0);

        // selectors for vault
        bytes4[] memory functionSelectorsVaultFacet = new bytes4[](28);
        functionSelectorsVaultFacet[0] = IERC20Metadata.name.selector;
        functionSelectorsVaultFacet[1] = IERC20Metadata.symbol.selector;
        functionSelectorsVaultFacet[2] = IERC20Metadata.decimals.selector;
        functionSelectorsVaultFacet[3] = IERC20.balanceOf.selector;
        functionSelectorsVaultFacet[4] = IERC20.approve.selector;
        functionSelectorsVaultFacet[5] = IERC20.transfer.selector;
        functionSelectorsVaultFacet[6] = IERC20.transferFrom.selector;
        functionSelectorsVaultFacet[7] = IERC20.allowance.selector;
        functionSelectorsVaultFacet[8] = IERC4626.asset.selector;
        functionSelectorsVaultFacet[9] = IERC4626.totalAssets.selector;
        functionSelectorsVaultFacet[10] = IERC4626.convertToAssets.selector;
        functionSelectorsVaultFacet[11] = IERC4626.convertToShares.selector;
        functionSelectorsVaultFacet[12] = IERC4626.maxDeposit.selector;
        functionSelectorsVaultFacet[13] = IERC4626.previewDeposit.selector;
        functionSelectorsVaultFacet[14] = IERC4626.deposit.selector;
        functionSelectorsVaultFacet[15] = IERC4626.maxMint.selector;
        functionSelectorsVaultFacet[16] = IERC4626.previewMint.selector;
        functionSelectorsVaultFacet[17] = IERC4626.mint.selector;
        functionSelectorsVaultFacet[18] = IERC4626.maxWithdraw.selector;
        functionSelectorsVaultFacet[19] = IERC4626.previewWithdraw.selector;
        functionSelectorsVaultFacet[20] = IERC4626.withdraw.selector;
        functionSelectorsVaultFacet[21] = IERC4626.maxRedeem.selector;
        functionSelectorsVaultFacet[22] = IERC4626.previewRedeem.selector;
        functionSelectorsVaultFacet[23] = IERC4626.redeem.selector;
        functionSelectorsVaultFacet[24] = bytes4(
            keccak256("deposit(address[],uint256[],address)")
        );
        functionSelectorsVaultFacet[25] = IVaultFacet.paused.selector;
        functionSelectorsVaultFacet[26] = IVaultFacet.pause.selector;
        functionSelectorsVaultFacet[27] = IVaultFacet.unpause.selector;

        bytes memory initDataVaultFacet = abi.encode(
            "More Vault",
            "MORE",
            config.wrappedNative(),
            config.feeRecipient(),
            100
        );

        // selectors for uniswap v2
        bytes4[] memory functionSelectorsUniswapV2Facet = new bytes4[](14);
        functionSelectorsUniswapV2Facet[0] = IUniswapV2Facet
            .accountingUniswapV2Facet
            .selector;
        functionSelectorsUniswapV2Facet[1] = IUniswapV2Facet
            .addLiquidity
            .selector;
        functionSelectorsUniswapV2Facet[2] = IUniswapV2Facet
            .addLiquidityETH
            .selector;
        functionSelectorsUniswapV2Facet[3] = IUniswapV2Facet
            .removeLiquidity
            .selector;
        functionSelectorsUniswapV2Facet[4] = IUniswapV2Facet
            .removeLiquidityETH
            .selector;
        functionSelectorsUniswapV2Facet[5] = IUniswapV2Facet
            .swapExactTokensForTokens
            .selector;
        functionSelectorsUniswapV2Facet[6] = IUniswapV2Facet
            .swapTokensForExactTokens
            .selector;
        functionSelectorsUniswapV2Facet[7] = IUniswapV2Facet
            .swapExactETHForTokens
            .selector;
        functionSelectorsUniswapV2Facet[8] = IUniswapV2Facet
            .swapTokensForExactETH
            .selector;
        functionSelectorsUniswapV2Facet[9] = IUniswapV2Facet
            .swapExactTokensForETH
            .selector;
        functionSelectorsUniswapV2Facet[10] = IUniswapV2Facet
            .swapETHForExactTokens
            .selector;
        functionSelectorsUniswapV2Facet[11] = IUniswapV2Facet
            .removeLiquidityETHSupportingFeeOnTransferTokens
            .selector;
        functionSelectorsUniswapV2Facet[12] = IUniswapV2Facet
            .swapExactTokensForTokensSupportingFeeOnTransferTokens
            .selector;
        functionSelectorsUniswapV2Facet[13] = IUniswapV2Facet
            .swapExactETHForTokensSupportingFeeOnTransferTokens
            .selector;

        bytes memory initDataUniswapV2Facet = abi.encode(address(uniswapV2));

        // selectors for origami
        bytes4[] memory functionSelectorsOrigamiFacet = new bytes4[](9);
        functionSelectorsOrigamiFacet[0] = IOrigamiFacet
            .accountingOrigamiFacet
            .selector;
        functionSelectorsOrigamiFacet[1] = IOrigamiFacet
            .investWithToken
            .selector;
        functionSelectorsOrigamiFacet[2] = IOrigamiFacet
            .investWithNative
            .selector;
        functionSelectorsOrigamiFacet[3] = IOrigamiFacet.exitToToken.selector;
        functionSelectorsOrigamiFacet[4] = IOrigamiFacet.exitToNative.selector;
        functionSelectorsOrigamiFacet[5] = IOrigamiFacet.rebalanceUp.selector;
        functionSelectorsOrigamiFacet[6] = IOrigamiFacet
            .forceRebalanceUp
            .selector;
        functionSelectorsOrigamiFacet[7] = IOrigamiFacet.rebalanceDown.selector;
        functionSelectorsOrigamiFacet[8] = IOrigamiFacet
            .forceRebalanceDown
            .selector;

        bytes memory initDataOrigamiFacet = abi.encode(address(origami));

        // selectors for more markets
        bytes4[] memory functionSelectorsMoreMarketsFacet = new bytes4[](13);
        functionSelectorsMoreMarketsFacet[0] = IMoreMarketsFacet
            .accountingMoreMarketsFacet
            .selector;
        functionSelectorsMoreMarketsFacet[1] = IMoreMarketsFacet
            .supply
            .selector;
        functionSelectorsMoreMarketsFacet[2] = IMoreMarketsFacet
            .withdraw
            .selector;
        functionSelectorsMoreMarketsFacet[3] = IMoreMarketsFacet
            .borrow
            .selector;
        functionSelectorsMoreMarketsFacet[4] = IMoreMarketsFacet.repay.selector;
        functionSelectorsMoreMarketsFacet[5] = IMoreMarketsFacet
            .repayWithATokens
            .selector;
        functionSelectorsMoreMarketsFacet[6] = IMoreMarketsFacet
            .swapBorrowRateMode
            .selector;
        functionSelectorsMoreMarketsFacet[7] = IMoreMarketsFacet
            .rebalanceStableBorrowRate
            .selector;
        functionSelectorsMoreMarketsFacet[8] = IMoreMarketsFacet
            .setUserUseReserveAsCollateral
            .selector;
        functionSelectorsMoreMarketsFacet[9] = IMoreMarketsFacet
            .flashLoan
            .selector;
        functionSelectorsMoreMarketsFacet[10] = IMoreMarketsFacet
            .flashLoanSimple
            .selector;
        functionSelectorsMoreMarketsFacet[11] = IMoreMarketsFacet
            .setUserEMode
            .selector;
        functionSelectorsMoreMarketsFacet[12] = IMoreMarketsFacet
            .claimAllRewards
            .selector;

        bytes memory initDataMoreMarketsFacet = abi.encode(
            address(moreMarkets)
        );

        // selectors for izumi swap
        bytes4[] memory functionSelectorsIzumiSwapFacet = new bytes4[](2);
        functionSelectorsIzumiSwapFacet[0] = IIzumiSwapFacet
            .swapAmount
            .selector;
        functionSelectorsIzumiSwapFacet[1] = IIzumiSwapFacet
            .swapDesire
            .selector;

        bytes memory initDataIzumiSwapFacet = abi.encode(address(izumiSwap));

        // selectors for aggro kitty swap
        bytes4[] memory functionSelectorsAggroKittySwapFacet = new bytes4[](3);
        functionSelectorsAggroKittySwapFacet[0] = IAggroKittySwapFacet
            .swapNoSplit
            .selector;
        functionSelectorsAggroKittySwapFacet[1] = IAggroKittySwapFacet
            .swapNoSplitFromNative
            .selector;
        functionSelectorsAggroKittySwapFacet[2] = IAggroKittySwapFacet
            .swapNoSplitToNative
            .selector;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](10);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsLoupeFacet,
            initData: ""
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(accessControl),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsAccessControlFacet,
            initData: initDataAccessControlFacet
        });
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(configuration),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsConfigurationFacet,
            initData: ""
        });
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(multicall),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsMulticallFacet,
            initData: initDataMulticallFacet
        });
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(vault),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsVaultFacet,
            initData: initDataVaultFacet
        });
        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: address(uniswapV2),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsUniswapV2Facet,
            initData: initDataUniswapV2Facet
        });
        cuts[6] = IDiamondCut.FacetCut({
            facetAddress: address(origami),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsOrigamiFacet,
            initData: initDataOrigamiFacet
        });
        cuts[7] = IDiamondCut.FacetCut({
            facetAddress: address(moreMarkets),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsMoreMarketsFacet,
            initData: initDataMoreMarketsFacet
        });
        cuts[8] = IDiamondCut.FacetCut({
            facetAddress: address(izumiSwap),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsIzumiSwapFacet,
            initData: initDataIzumiSwapFacet
        });
        cuts[9] = IDiamondCut.FacetCut({
            facetAddress: address(aggroKittySwap),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsAggroKittySwapFacet,
            initData: ""
        });

        return cuts;
    }
}

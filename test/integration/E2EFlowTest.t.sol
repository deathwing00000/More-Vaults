// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {VaultsRegistry} from "../../src/registry/VaultsRegistry.sol";
import {VaultsFactory} from "../../src/factory/VaultsFactory.sol";
import {MoreVaultsDiamond} from "../../src/MoreVaultsDiamond.sol";
import {IDiamondCut, DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";
import {IERC165, IDiamondLoupe, DiamondLoupeFacet} from "../../src/facets/DiamondLoupeFacet.sol";
import {IAccessControlFacet, AccessControlFacet} from "../../src/facets/AccessControlFacet.sol";
import {IConfigurationFacet, ConfigurationFacet} from "../../src/facets/ConfigurationFacet.sol";
import {IMulticallFacet, MulticallFacet} from "../../src/facets/MulticallFacet.sol";
import {IVaultFacet, VaultFacet} from "../../src/facets/VaultFacet.sol";
import {IUniswapV2Facet, UniswapV2Facet} from "../../src/facets/UniswapV2Facet.sol";
import {IOrigamiFacet, OrigamiFacet} from "../../src/facets/OrigamiFacet.sol";
import {IPool, IMoreMarketsFacet, MoreMarketsFacet} from "../../src/facets/MoreMarketsFacet.sol";
import {IIzumiSwapFacet, IzumiSwapFacet} from "../../src/facets/IzumiSwapFacet.sol";
import {MoreVaultsStorageHelper} from "../helper/MoreVaultsStorageHelper.sol";
import {AccessControlLib} from "../../src/libraries/AccessControlLib.sol";
import {MoreVaultsLib} from "../../src/libraries/MoreVaultsLib.sol";
import {IMoreVaultsRegistry} from "../../src/interfaces/IMoreVaultsRegistry.sol";
import {IVaultsFactory} from "../../src/interfaces/IVaultsFactory.sol";
import {IVaultFacet} from "../../src/interfaces/facets/IVaultFacet.sol";
import {IUniswapV2Router02, IUniswapV2Router01} from "../../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IOrigamiInvestment} from "../../src/interfaces/Origami/IOrigamiInvestment.sol";
import {ISwap} from "../../src/interfaces/iZUMi/ISwap.sol";
import {IAggroKittySwapFacet, AggroKittySwapFacet} from "../../src/facets/AggroKittySwapFacet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {console} from "forge-std/console.sol";

contract E2EFlowTest is Test {
    string constant VAULT_NAME = "Test Vault";
    string constant VAULT_SYMBOL = "TV";

    // Test addresses
    address constant OWNER = address(0x1);
    address constant CURATOR = address(0x2);
    address constant USER = address(0x3);
    address constant GUARDIAN = address(0x4);
    address constant FEE_RECIPIENT = address(0x5);
    address constant TREASURY = address(0x6);
    address constant ORIGAMI_LOV_TOKEN =
        address(0x87fDa685d17865825474d99d5153b8a17c402bA5);
    address constant IZUMI_POOL = address(0x8);
    address constant UNISWAP_ROUTER =
        address(0xeD53235cC3E9d2d464E9c408B95948836648870B);
    address constant MORE_MARKETS_POOL =
        address(0x48Dad407aB7299E0175F39F4Cd12c524DB0AB002);
    address constant SEEKER_ADDRESS =
        address(0xd0cb86aAD548a6d2f576D24dbEf33204960f6Afe);

    // Test tokens
    address constant USDCe =
        address(0xbC462009560a9270bdB9A2bFA2efa1AD533793eb);
    address constant cbBTC =
        address(0x30F44C64725727F2001E6C1eF6e6CE9c7aB91dC3);
    address constant WFLOW =
        address(0xd3bF53DAC106A0290B0483EcBC89d40FcC961f3e);
    address constant ankrFLOW =
        address(0x8E3DC6E937B560ce6a1Aaa78AfC775228969D16c);

    address constant AaveOracle =
        address(0x441eD9f8F67a776569F7aA3CcaCAD90AFBCBFD7B);

    // Test constants
    uint256 constant INITIAL_BALANCE = 1000000e18;
    uint256 constant DEPOSIT_AMOUNT = 1000e18;
    uint256 constant MIN_AMOUNT_OUT = 900e18;
    uint256 public deadline;

    // Contracts
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

    // Mock tokens
    IERC20 usdce;
    IERC20 cbbtc;
    IERC20 wflow;
    IERC20 ankrflow;

    address vaultAddress;

    function setUp() public {
        deadline = block.timestamp + 1 hours;

        // Fork Flow EVM testnet
        vm.createSelectFork(vm.envString("FLOW_EVM_TESTNET_RPC_URL"));
        vm.rollFork(39542534);

        // Deploy mock tokens
        usdce = IERC20(USDCe);
        cbbtc = IERC20(cbBTC);
        wflow = IERC20(WFLOW);
        ankrflow = IERC20(ankrFLOW);

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

        // Deploy registry
        registry = new VaultsRegistry();
        registry.initialize(AaveOracle, USDCe);
        bytes4[] memory functionSelectorsDiamondCutFacet = new bytes4[](1);
        functionSelectorsDiamondCutFacet[0] = IDiamondCut.diamondCut.selector;
        registry.addFacet(
            address(diamondCut),
            functionSelectorsDiamondCutFacet
        );

        IDiamondCut.FacetCut[] memory cuts = _getCuts();

        for (uint i = 0; i < cuts.length; ) {
            registry.addFacet(cuts[i].facetAddress, cuts[i].functionSelectors);
            unchecked {
                ++i;
            }
        }

        // Deploy factory
        factory = new VaultsFactory();
        factory.initialize(address(registry), address(diamondCut), WFLOW);

        // Deploy diamond
        vaultAddress = factory.deployVault(cuts);

        // Setup mock tokens
        deal(USDCe, USER, INITIAL_BALANCE);
        deal(cbBTC, USER, INITIAL_BALANCE);
        deal(WFLOW, USER, INITIAL_BALANCE);
        deal(ankrFLOW, USER, INITIAL_BALANCE);
    }

    function testE2EFlow() public {
        // Create vault
        vm.startPrank(CURATOR);
        address[] memory availableAssets = new address[](3);
        availableAssets[0] = address(cbbtc);
        availableAssets[1] = address(ankrflow);
        availableAssets[2] = address(usdce);
        IConfigurationFacet(vaultAddress).addAvailableAssets(availableAssets);
        vm.stopPrank();

        // Approve tokens
        vm.startPrank(USER);
        usdce.approve(vaultAddress, DEPOSIT_AMOUNT);
        cbbtc.approve(vaultAddress, DEPOSIT_AMOUNT);
        wflow.approve(vaultAddress, DEPOSIT_AMOUNT);
        ankrflow.approve(vaultAddress, DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(USER);
        vm.deal(USER, DEPOSIT_AMOUNT);
        IERC4626(vaultAddress).deposit(DEPOSIT_AMOUNT, USER);
        vm.stopPrank();

        assertEq(IERC4626(vaultAddress).balanceOf(USER), DEPOSIT_AMOUNT);
        assertEq(IERC4626(vaultAddress).totalAssets(), DEPOSIT_AMOUNT);
        assertEq(
            IERC4626(vaultAddress).convertToAssets(DEPOSIT_AMOUNT),
            DEPOSIT_AMOUNT
        );
        assertEq(
            IERC4626(vaultAddress).convertToShares(DEPOSIT_AMOUNT),
            DEPOSIT_AMOUNT
        );

        address[] memory availableAssets2 = IConfigurationFacet(vaultAddress)
            .getAvailableAssets();
        for (uint i; i < availableAssets2.length; ) {
            unchecked {
                ++i;
            }
        }
        vm.startPrank(CURATOR);
        bytes[] memory actions = new bytes[](1);
        actions[0] = abi.encodeWithSelector(
            IMoreMarketsFacet.supply.selector,
            MORE_MARKETS_POOL,
            address(WFLOW),
            DEPOSIT_AMOUNT,
            0
        );

        IMulticallFacet(vaultAddress).submitActions(actions);
        assertEq(wflow.balanceOf(address(vaultAddress)), 0);
        address mToken = IPool(MORE_MARKETS_POOL)
            .getReserveData(address(WFLOW))
            .aTokenAddress;
        assertGt(IERC20(mToken).balanceOf(address(vaultAddress)), 0);
        console.log(
            "mToken balance",
            IERC20(mToken).balanceOf(address(vaultAddress))
        );
        vm.stopPrank();
    }

    function _getPath(
        address tokenIn,
        address tokenOut
    ) internal pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        return path;
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
            OWNER,
            CURATOR,
            GUARDIAN,
            address(registry)
        );

        // selectors for configuration
        bytes4[] memory functionSelectorsConfigurationFacet = new bytes4[](11);
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
        functionSelectorsConfigurationFacet[7] = ConfigurationFacet
            .fee
            .selector;
        functionSelectorsConfigurationFacet[8] = ConfigurationFacet
            .depositCapacity
            .selector;
        functionSelectorsConfigurationFacet[9] = ConfigurationFacet
            .timeLockPeriod
            .selector;
        functionSelectorsConfigurationFacet[10] = ConfigurationFacet
            .feeRecipient
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
        // Multi-token deposit function
        functionSelectorsVaultFacet[24] = bytes4(
            keccak256("deposit(address[],uint256[],address)")
        );
        functionSelectorsVaultFacet[25] = IVaultFacet.paused.selector;
        functionSelectorsVaultFacet[26] = IVaultFacet.pause.selector;
        functionSelectorsVaultFacet[27] = IVaultFacet.unpause.selector;

        bytes memory initDataVaultFacet = abi.encode(
            VAULT_NAME,
            VAULT_SYMBOL,
            WFLOW,
            FEE_RECIPIENT,
            100,
            1000000 ether
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

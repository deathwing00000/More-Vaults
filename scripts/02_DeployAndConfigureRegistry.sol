// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {DeployUtils} from "./utils/DeployUtils.sol";
import {VaultsRegistry} from "../src/VaultsRegistry.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";
import {IAccessControlFacet} from "../src/interfaces/facets/IAccessControlFacet.sol";
import {IConfigurationFacet} from "../src/interfaces/facets/IConfigurationFacet.sol";
import {IMulticallFacet} from "../src/interfaces/facets/IMulticallFacet.sol";
import {IUniswapV2Facet} from "../src/interfaces/facets/IUniswapV2Facet.sol";
import {IIzumiSwapFacet} from "../src/interfaces/facets/IIzumiSwapFacet.sol";
import {IMoreMarketsFacet} from "../src/interfaces/facets/IMoreMarketsFacet.sol";
import {IOrigamiFacet} from "../src/interfaces/facets/IOrigamiFacet.sol";
import {IVaultFacet} from "../src/interfaces/facets/IVaultFacet.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract DeployAndConfigureRegistry is Script, DeployUtils {
    function run() external {
        uint256 deployerPrivateKey = readPrivateKey();

        // Read facet addresses from previous deployment
        address diamondCutFacet = vm.envAddress("DIAMOND_CUT_FACET");
        address diamondLoupeFacet = vm.envAddress("DIAMOND_LOUPE_FACET");
        address accessControlFacet = vm.envAddress("ACCESS_CONTROL_FACET");
        address configurationFacet = vm.envAddress("CONFIGURATION_FACET");
        address origamiFacet = vm.envAddress("ORIGAMI_FACET");
        address moreMarketsFacet = vm.envAddress("MORE_MARKETS_FACET");
        address vaultFacet = vm.envAddress("VAULT_FACET");
        address multicallFacet = vm.envAddress("MULTICALL_FACET");
        address uniswapV2Facet = vm.envAddress("UNISWAP_V2_FACET");
        address izumiSwapFacet = vm.envAddress("IZUMI_SWAP_FACET");

        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        address aaveOracleAddress = vm.envAddress("AAVE_ORACLE_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy registry
        VaultsRegistry registry = new VaultsRegistry(
            usdcAddress,
            aaveOracleAddress
        );
        // verifyContract(address(registry), "");
        console2.log("VaultsRegistry deployed at:", address(registry));

        // ============ Diamond Core Facets ============
        // DiamondCut - handles diamond upgrades
        bytes4[] memory diamondCutSelectors = new bytes4[](1);
        diamondCutSelectors[0] = IDiamondCut.diamondCut.selector;
        registry.addFacet(diamondCutFacet, diamondCutSelectors);

        // DiamondLoupe - provides introspection functions
        bytes4[] memory diamondLoupeSelectors = new bytes4[](4);
        diamondLoupeSelectors[0] = IDiamondLoupe.facets.selector;
        diamondLoupeSelectors[1] = IDiamondLoupe
            .facetFunctionSelectors
            .selector;
        diamondLoupeSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        diamondLoupeSelectors[3] = IDiamondLoupe.facetAddress.selector;
        registry.addFacet(diamondLoupeFacet, diamondLoupeSelectors);

        // ============ Access Control Facets ============
        // AccessControl - handles roles and permissions
        bytes4[] memory accessControlSelectors = new bytes4[](4);
        accessControlSelectors[0] = IAccessControlFacet
            .transferCuratorship
            .selector;
        accessControlSelectors[1] = IAccessControlFacet
            .transferGuardian
            .selector;
        accessControlSelectors[2] = IAccessControlFacet.curator.selector;
        accessControlSelectors[3] = IAccessControlFacet.guardian.selector;
        registry.addFacet(accessControlFacet, accessControlSelectors);

        // ============ Configuration Facets ============
        // Configuration - handles vault settings
        bytes4[] memory configurationSelectors = new bytes4[](7);
        configurationSelectors[0] = IConfigurationFacet
            .setFeeRecipient
            .selector;
        configurationSelectors[1] = IConfigurationFacet.setFee.selector;
        configurationSelectors[2] = IConfigurationFacet
            .setTimeLockPeriod
            .selector;
        configurationSelectors[3] = IConfigurationFacet
            .addAvailableAsset
            .selector;
        configurationSelectors[4] = IConfigurationFacet
            .addAvailableAssets
            .selector;
        configurationSelectors[5] = IConfigurationFacet
            .isAssetAvailable
            .selector;
        configurationSelectors[6] = IConfigurationFacet
            .getAvailableAssets
            .selector;
        registry.addFacet(configurationFacet, configurationSelectors);

        // ============ Core Vault Facets ============
        // Vault - implements ERC4626 and Pausable functionality
        bytes4[] memory vaultSelectors = new bytes4[](20);
        // ERC4626 functions
        vaultSelectors[0] = IERC4626.asset.selector;
        vaultSelectors[1] = IERC4626.totalAssets.selector;
        vaultSelectors[2] = IERC4626.convertToShares.selector;
        vaultSelectors[3] = IERC4626.convertToAssets.selector;
        vaultSelectors[4] = IERC4626.maxDeposit.selector;
        vaultSelectors[5] = IERC4626.previewDeposit.selector;
        vaultSelectors[6] = IERC4626.deposit.selector;
        vaultSelectors[7] = IERC4626.maxMint.selector;
        vaultSelectors[8] = IERC4626.previewMint.selector;
        vaultSelectors[9] = IERC4626.mint.selector;
        vaultSelectors[10] = IERC4626.maxWithdraw.selector;
        vaultSelectors[11] = IERC4626.previewWithdraw.selector;
        vaultSelectors[12] = IERC4626.withdraw.selector;
        vaultSelectors[13] = IERC4626.maxRedeem.selector;
        vaultSelectors[14] = IERC4626.previewRedeem.selector;
        vaultSelectors[15] = IERC4626.redeem.selector;
        // Multi-token deposit function
        vaultSelectors[16] = bytes4(
            keccak256("deposit(address[],uint256[],address)")
        );
        vaultSelectors[17] = IVaultFacet.paused.selector;
        vaultSelectors[18] = IVaultFacet.pause.selector;
        vaultSelectors[19] = IVaultFacet.unpause.selector;
        registry.addFacet(vaultFacet, vaultSelectors);

        // ============ Utility Facets ============
        // Multicall - allows batching multiple calls
        bytes4[] memory multicallSelectors = new bytes4[](5);
        multicallSelectors[0] = IMulticallFacet.submitActions.selector;
        multicallSelectors[1] = IMulticallFacet.executeActions.selector;
        multicallSelectors[2] = IMulticallFacet.vetoActions.selector;
        multicallSelectors[3] = IMulticallFacet.getPendingActions.selector;
        multicallSelectors[4] = IMulticallFacet.getCurrentNonce.selector;
        registry.addFacet(multicallFacet, multicallSelectors);

        // ============ DEX Integration Facets ============
        // UniswapV2 - handles Uniswap V2 interactions
        bytes4[] memory uniswapV2Selectors = new bytes4[](19);
        uniswapV2Selectors[0] = IUniswapV2Facet
            .accountingUniswapV2Facet
            .selector;
        uniswapV2Selectors[1] = IUniswapV2Facet.addLiquidity.selector;
        uniswapV2Selectors[2] = IUniswapV2Facet.addLiquidityETH.selector;
        uniswapV2Selectors[3] = IUniswapV2Facet.removeLiquidity.selector;
        uniswapV2Selectors[4] = IUniswapV2Facet.removeLiquidityETH.selector;
        uniswapV2Selectors[5] = IUniswapV2Facet
            .swapExactTokensForTokens
            .selector;
        uniswapV2Selectors[6] = IUniswapV2Facet
            .swapTokensForExactTokens
            .selector;
        uniswapV2Selectors[7] = IUniswapV2Facet.swapExactETHForTokens.selector;
        uniswapV2Selectors[8] = IUniswapV2Facet.swapTokensForExactETH.selector;
        uniswapV2Selectors[9] = IUniswapV2Facet.swapExactTokensForETH.selector;
        uniswapV2Selectors[10] = IUniswapV2Facet.swapETHForExactTokens.selector;
        uniswapV2Selectors[11] = IUniswapV2Facet.quote.selector;
        uniswapV2Selectors[12] = IUniswapV2Facet.getAmountOut.selector;
        uniswapV2Selectors[13] = IUniswapV2Facet.getAmountIn.selector;
        uniswapV2Selectors[14] = IUniswapV2Facet.getAmountsOut.selector;
        uniswapV2Selectors[15] = IUniswapV2Facet.getAmountsIn.selector;
        uniswapV2Selectors[16] = IUniswapV2Facet
            .removeLiquidityETHSupportingFeeOnTransferTokens
            .selector;
        uniswapV2Selectors[17] = IUniswapV2Facet
            .swapExactTokensForTokensSupportingFeeOnTransferTokens
            .selector;
        uniswapV2Selectors[18] = IUniswapV2Facet
            .swapExactETHForTokensSupportingFeeOnTransferTokens
            .selector;
        registry.addFacet(uniswapV2Facet, uniswapV2Selectors);

        // IzumiSwap - handles iZUMi DEX interactions
        bytes4[] memory izumiSwapSelectors = new bytes4[](2);
        izumiSwapSelectors[0] = IIzumiSwapFacet.swapAmount.selector;
        izumiSwapSelectors[1] = IIzumiSwapFacet.swapDesire.selector;
        registry.addFacet(izumiSwapFacet, izumiSwapSelectors);

        // ============ Lending Protocol Facets ============
        // MoreMarkets - handles Aave V3 interactions
        bytes4[] memory moreMarketsSelectors = new bytes4[](14);
        moreMarketsSelectors[0] = IMoreMarketsFacet
            .accountingMoreMarketsFacet
            .selector;
        moreMarketsSelectors[1] = IMoreMarketsFacet.approveDelegation.selector;
        moreMarketsSelectors[2] = IMoreMarketsFacet.supply.selector;
        moreMarketsSelectors[3] = IMoreMarketsFacet.withdraw.selector;
        moreMarketsSelectors[4] = IMoreMarketsFacet.borrow.selector;
        moreMarketsSelectors[5] = IMoreMarketsFacet.repay.selector;
        moreMarketsSelectors[6] = IMoreMarketsFacet.repayWithATokens.selector;
        moreMarketsSelectors[7] = IMoreMarketsFacet.swapBorrowRateMode.selector;
        moreMarketsSelectors[8] = IMoreMarketsFacet
            .rebalanceStableBorrowRate
            .selector;
        moreMarketsSelectors[9] = IMoreMarketsFacet
            .setUserUseReserveAsCollateral
            .selector;
        moreMarketsSelectors[10] = IMoreMarketsFacet.flashLoan.selector;
        moreMarketsSelectors[11] = IMoreMarketsFacet.flashLoanSimple.selector;
        moreMarketsSelectors[12] = IMoreMarketsFacet.setUserEMode.selector;
        moreMarketsSelectors[13] = IMoreMarketsFacet.claimAllRewards.selector;
        registry.addFacet(moreMarketsFacet, moreMarketsSelectors);

        // ============ Yield Protocol Facets ============
        // Origami - handles Origami protocol interactions
        bytes4[] memory origamiSelectors = new bytes4[](10);
        origamiSelectors[0] = IOrigamiFacet.accountingOrigamiFacet.selector;
        origamiSelectors[1] = IOrigamiFacet.investWithToken.selector;
        origamiSelectors[2] = IOrigamiFacet.investWithNative.selector;
        origamiSelectors[3] = IOrigamiFacet.exitToToken.selector;
        origamiSelectors[4] = IOrigamiFacet.exitToNative.selector;
        origamiSelectors[5] = IOrigamiFacet.rebalanceUp.selector;
        origamiSelectors[6] = IOrigamiFacet.forceRebalanceUp.selector;
        origamiSelectors[7] = IOrigamiFacet.rebalanceDown.selector;
        origamiSelectors[8] = IOrigamiFacet.forceRebalanceDown.selector;
        registry.addFacet(origamiFacet, origamiSelectors);

        vm.stopBroadcast();

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
    }
}

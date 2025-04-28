// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDiamondCut, DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";
import {IERC165, IDiamondLoupe, DiamondLoupeFacet} from "../../src/facets/DiamondLoupeFacet.sol";
import {IAccessControlFacet, AccessControlFacet} from "../../src/facets/AccessControlFacet.sol";
import {IConfigurationFacet, ConfigurationFacet} from "../../src/facets/ConfigurationFacet.sol";
import {IMulticallFacet, MulticallFacet} from "../../src/facets/MulticallFacet.sol";
import {IVaultFacet, IERC4626, IERC20, VaultFacet} from "../../src/facets/VaultFacet.sol";
import {IUniswapV2Facet, UniswapV2Facet} from "../../src/facets/UniswapV2Facet.sol";
import {IOrigamiFacet, OrigamiFacet} from "../../src/facets/OrigamiFacet.sol";
import {IPool, IMoreMarketsFacet, MoreMarketsFacet} from "../../src/facets/MoreMarketsFacet.sol";
import {IIzumiSwapFacet, IzumiSwapFacet} from "../../src/facets/IzumiSwapFacet.sol";
import {IAggroKittySwapFacet, AggroKittySwapFacet} from "../../src/facets/AggroKittySwapFacet.sol";
import {ICurveFacet, CurveFacet} from "../../src/facets/CurveFacet.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

contract DeployConfig {
    // Roles
    address public owner;
    address public curator;
    address public guardian;
    address public feeRecipient;
    address public treasury;

    // Tokens
    address public wrappedNative;
    address public usdce;
    address public aaveOracle;

    uint96 public fee;
    uint256 public depositCapacity;
    uint256 public timeLockPeriod;

    constructor(
        address _owner,
        address _curator,
        address _guardian,
        address _feeRecipient,
        address _treasury,
        address _wrappedNative,
        address _usdce,
        address _aaveOracle,
        uint96 _fee,
        uint256 _depositCapacity,
        uint256 _timeLockPeriod
    ) {
        owner = _owner;
        curator = _curator;
        guardian = _guardian;
        feeRecipient = _feeRecipient;
        treasury = _treasury;
        wrappedNative = _wrappedNative;
        usdce = _usdce;
        aaveOracle = _aaveOracle;
        fee = _fee;
        depositCapacity = _depositCapacity;
        timeLockPeriod = _timeLockPeriod;
    }

    function getCuts(
        address diamondLoupe,
        address accessControl,
        address configuration,
        address multicall,
        address vault,
        address uniswapV2,
        address origami,
        address moreMarkets,
        address izumiSwap,
        address aggroKittySwap,
        address curve
    ) external view returns (IDiamondCut.FacetCut[] memory) {
        /// DEFAULT FACETS

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
            owner,
            curator,
            guardian
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
        bytes memory initDataMulticallFacet = abi.encode(timeLockPeriod);

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
            wrappedNative,
            feeRecipient,
            fee,
            depositCapacity
        );

        /// OPTIONAL FACETS

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

        // selectors for curve
        bytes4[] memory functionSelectorsCurveFacet = new bytes4[](1);
        functionSelectorsCurveFacet[0] = ICurveFacet.exchange.selector;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](11);
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
            initData: ""
        });
        cuts[9] = IDiamondCut.FacetCut({
            facetAddress: address(aggroKittySwap),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsAggroKittySwapFacet,
            initData: ""
        });
        cuts[10] = IDiamondCut.FacetCut({
            facetAddress: address(curve),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsCurveFacet,
            initData: ""
        });

        return cuts;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDiamondCut, DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";
import {IERC165, IDiamondLoupe, DiamondLoupeFacet} from "../../src/facets/DiamondLoupeFacet.sol";
import {IAccessControlFacet, AccessControlFacet} from "../../src/facets/AccessControlFacet.sol";
import {IConfigurationFacet, ConfigurationFacet} from "../../src/facets/ConfigurationFacet.sol";
import {IMulticallFacet, MulticallFacet} from "../../src/facets/MulticallFacet.sol";
import {IVaultFacet, IERC4626, IERC20, VaultFacet} from "../../src/facets/VaultFacet.sol";
import {IUniswapV2Facet, UniswapV2Facet} from "../../src/facets/UniswapV2Facet.sol";
import {IMORELeverageFacet, MORELeverageFacet} from "../../src/facets/MORELeverageFacet.sol";
import {IPool, IAaveV3Facet, AaveV3Facet} from "../../src/facets/AaveV3Facet.sol";
import {IIzumiSwapFacet, IzumiSwapFacet} from "../../src/facets/IzumiSwapFacet.sol";
import {IAggroKittySwapFacet, AggroKittySwapFacet} from "../../src/facets/AggroKittySwapFacet.sol";
import {ICurveFacet, CurveFacet} from "../../src/facets/CurveFacet.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IUniswapV3Facet, UniswapV3Facet} from "../../src/facets/UniswapV3Facet.sol";
import {IMultiRewardsFacet, MultiRewardsFacet} from "../../src/facets/MultiRewardsFacet.sol";
import {ICurveLiquidityGaugeV6Facet, CurveLiquidityGaugeV6Facet} from "../../src/facets/CurveLiquidityGaugeV6Facet.sol";

contract DeployConfig {
    // Roles
    address public owner;
    address public curator;
    address public guardian;
    address public feeRecipient;

    // Tokens
    address public assetToDeposit;
    address public wrappedNative;
    address public usdce;
    address public aaveOracle;

    uint96 public fee;
    uint256 public depositCapacity;
    uint256 public timeLockPeriod;

    struct FacetAddresses {
        address diamondLoupe;
        address accessControl;
        address configuration;
        address multicall;
        address vault;
        address uniswapV2;
        address origami;
        address moreMarkets;
        address izumiSwap;
        address aggroKittySwap;
        address curve;
        address uniswapV3;
        address multiRewards;
        address curveGaugeV6;
    }

    function initParamsForProtocolDeployment(
        address _wrappedNative,
        address _usdce,
        address _aaveOracle
    ) external {
        wrappedNative = _wrappedNative;
        usdce = _usdce;
        aaveOracle = _aaveOracle;
    }

    function initParamsForVaultCreation(
        address _owner,
        address _curator,
        address _guardian,
        address _feeRecipient,
        address _assetToDeposit,
        uint96 _fee,
        uint256 _depositCapacity,
        uint256 _timeLockPeriod
    ) external {
        owner = _owner;
        curator = _curator;
        guardian = _guardian;
        feeRecipient = _feeRecipient;
        assetToDeposit = _assetToDeposit;
        fee = _fee;
        depositCapacity = _depositCapacity;
        timeLockPeriod = _timeLockPeriod;
    }

    function getCuts(
        FacetAddresses memory facetAddresses
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
        bytes4[] memory functionSelectorsAccessControlFacet = new bytes4[](8);
        functionSelectorsAccessControlFacet[0] = AccessControlFacet
            .setMoreVaultRegistry
            .selector;
        functionSelectorsAccessControlFacet[1] = AccessControlFacet
            .transferCuratorship
            .selector;
        functionSelectorsAccessControlFacet[2] = AccessControlFacet
            .transferOwner
            .selector;
        functionSelectorsAccessControlFacet[3] = AccessControlFacet
            .transferGuardian
            .selector;
        functionSelectorsAccessControlFacet[4] = AccessControlFacet
            .owner
            .selector;
        functionSelectorsAccessControlFacet[5] = AccessControlFacet
            .curator
            .selector;
        functionSelectorsAccessControlFacet[6] = AccessControlFacet
            .guardian
            .selector;
        functionSelectorsAccessControlFacet[7] = AccessControlFacet
            .moreVaultsRegistry
            .selector;

        bytes memory initDataAccessControlFacet = abi.encode(
            owner,
            curator,
            guardian
        );

        // selectors for configuration
        bytes4[] memory functionSelectorsConfigurationFacet = new bytes4[](15);
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
            .setDepositCapacity
            .selector;
        functionSelectorsConfigurationFacet[4] = ConfigurationFacet
            .addAvailableAsset
            .selector;
        functionSelectorsConfigurationFacet[5] = ConfigurationFacet
            .addAvailableAssets
            .selector;
        functionSelectorsConfigurationFacet[6] = ConfigurationFacet
            .enableAssetToDeposit
            .selector;
        functionSelectorsConfigurationFacet[7] = ConfigurationFacet
            .disableAssetToDeposit
            .selector;
        functionSelectorsConfigurationFacet[8] = ConfigurationFacet
            .isAssetAvailable
            .selector;
        functionSelectorsConfigurationFacet[9] = ConfigurationFacet
            .isAssetDepositable
            .selector;
        functionSelectorsConfigurationFacet[10] = ConfigurationFacet
            .getAvailableAssets
            .selector;
        functionSelectorsConfigurationFacet[11] = ConfigurationFacet
            .fee
            .selector;
        functionSelectorsConfigurationFacet[12] = ConfigurationFacet
            .depositCapacity
            .selector;
        functionSelectorsConfigurationFacet[13] = ConfigurationFacet
            .timeLockPeriod
            .selector;
        functionSelectorsConfigurationFacet[14] = ConfigurationFacet
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
            assetToDeposit,
            feeRecipient,
            fee,
            depositCapacity
        );

        /// OPTIONAL FACETS

        // selectors for uniswap v2
        bytes4[] memory functionSelectorsUniswapV2Facet = new bytes4[](15);
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
        functionSelectorsUniswapV2Facet[14] = IUniswapV2Facet
            .swapExactTokensForETHSupportingFeeOnTransferTokens
            .selector;

        bytes memory initDataUniswapV2Facet = abi.encode(
            facetAddresses.uniswapV2
        );

        // selectors for origami
        bytes4[] memory functionSelectorsMORELeverageFacet = new bytes4[](9);
        functionSelectorsMORELeverageFacet[0] = IMORELeverageFacet
            .accountingMORELeverageFacet
            .selector;
        functionSelectorsMORELeverageFacet[1] = IMORELeverageFacet
            .investWithToken
            .selector;
        functionSelectorsMORELeverageFacet[2] = IMORELeverageFacet
            .investWithNative
            .selector;
        functionSelectorsMORELeverageFacet[3] = IMORELeverageFacet
            .exitToToken
            .selector;
        functionSelectorsMORELeverageFacet[4] = IMORELeverageFacet
            .exitToNative
            .selector;
        functionSelectorsMORELeverageFacet[5] = IMORELeverageFacet
            .rebalanceUp
            .selector;
        functionSelectorsMORELeverageFacet[6] = IMORELeverageFacet
            .forceRebalanceUp
            .selector;
        functionSelectorsMORELeverageFacet[7] = IMORELeverageFacet
            .rebalanceDown
            .selector;
        functionSelectorsMORELeverageFacet[8] = IMORELeverageFacet
            .forceRebalanceDown
            .selector;

        bytes memory initDataMORELeverageFacet = abi.encode(
            facetAddresses.origami
        );

        // selectors for more markets
        bytes4[] memory functionSelectorsAaveV3Facet = new bytes4[](13);
        functionSelectorsAaveV3Facet[0] = IAaveV3Facet
            .accountingAaveV3Facet
            .selector;
        functionSelectorsAaveV3Facet[1] = IAaveV3Facet.supply.selector;
        functionSelectorsAaveV3Facet[2] = IAaveV3Facet.withdraw.selector;
        functionSelectorsAaveV3Facet[3] = IAaveV3Facet.borrow.selector;
        functionSelectorsAaveV3Facet[4] = IAaveV3Facet.repay.selector;
        functionSelectorsAaveV3Facet[5] = IAaveV3Facet
            .repayWithATokens
            .selector;
        functionSelectorsAaveV3Facet[6] = IAaveV3Facet
            .swapBorrowRateMode
            .selector;
        functionSelectorsAaveV3Facet[7] = IAaveV3Facet
            .rebalanceStableBorrowRate
            .selector;
        functionSelectorsAaveV3Facet[8] = IAaveV3Facet
            .setUserUseReserveAsCollateral
            .selector;
        functionSelectorsAaveV3Facet[9] = IAaveV3Facet.flashLoan.selector;
        functionSelectorsAaveV3Facet[10] = IAaveV3Facet
            .flashLoanSimple
            .selector;
        functionSelectorsAaveV3Facet[11] = IAaveV3Facet.setUserEMode.selector;
        functionSelectorsAaveV3Facet[12] = IAaveV3Facet
            .claimAllRewards
            .selector;

        bytes memory initDataAaveV3Facet = abi.encode(
            facetAddresses.moreMarkets
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
        bytes4[] memory functionSelectorsCurveFacet = new bytes4[](3);
        functionSelectorsCurveFacet[0] = ICurveFacet.exchangeNg.selector;
        functionSelectorsCurveFacet[1] = ICurveFacet.exchange.selector;
        functionSelectorsCurveFacet[2] = ICurveFacet
            .accountingCurveFacet
            .selector;
        bytes memory initDataCurveFacet = abi.encode(facetAddresses.curve);

        // selectors for UniswapV3
        bytes4[] memory functionSelectorsUniswapV3Facet = new bytes4[](4);
        functionSelectorsUniswapV3Facet[0] = IUniswapV3Facet
            .exactInput
            .selector;
        functionSelectorsUniswapV3Facet[1] = IUniswapV3Facet
            .exactInputSingle
            .selector;
        functionSelectorsUniswapV3Facet[2] = IUniswapV3Facet
            .exactOutput
            .selector;
        functionSelectorsUniswapV3Facet[3] = IUniswapV3Facet
            .exactOutputSingle
            .selector;

        bytes4[] memory functionSelectorsMultiRewardsFacet = new bytes4[](5);
        functionSelectorsMultiRewardsFacet[0] = IMultiRewardsFacet
            .accountingMultiRewardsFacet
            .selector;
        functionSelectorsMultiRewardsFacet[1] = IMultiRewardsFacet
            .stake
            .selector;
        functionSelectorsMultiRewardsFacet[2] = IMultiRewardsFacet
            .withdraw
            .selector;
        functionSelectorsMultiRewardsFacet[3] = IMultiRewardsFacet
            .getReward
            .selector;
        functionSelectorsMultiRewardsFacet[4] = IMultiRewardsFacet
            .exit
            .selector;
        bytes memory initDataMultiRewardsFacet = abi.encode(
            facetAddresses.multiRewards
        );

        // selectors for CurveLiquidityGaugeV6Facet
        bytes4[]
            memory functionSelectorsCurveLiquidityGaugeV6Facet = new bytes4[](
                5
            );
        functionSelectorsCurveLiquidityGaugeV6Facet[
            0
        ] = ICurveLiquidityGaugeV6Facet
            .accountingCurveLiquidityGaugeV6Facet
            .selector;
        functionSelectorsCurveLiquidityGaugeV6Facet[
            1
        ] = ICurveLiquidityGaugeV6Facet.depositCurveGaugeV6.selector;
        functionSelectorsCurveLiquidityGaugeV6Facet[
            2
        ] = ICurveLiquidityGaugeV6Facet.withdrawCurveGaugeV6.selector;
        functionSelectorsCurveLiquidityGaugeV6Facet[
            3
        ] = ICurveLiquidityGaugeV6Facet.claimRewardsCurveGaugeV6.selector;
        functionSelectorsCurveLiquidityGaugeV6Facet[
            4
        ] = ICurveLiquidityGaugeV6Facet.mintCRV.selector;
        bytes memory initDataCurveLiquidityGaugeV6Facet = abi.encode(
            facetAddresses.curveGaugeV6
        );

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](14);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.diamondLoupe,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsLoupeFacet,
            initData: ""
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.accessControl,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsAccessControlFacet,
            initData: initDataAccessControlFacet
        });
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.configuration,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsConfigurationFacet,
            initData: ""
        });
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.multicall,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsMulticallFacet,
            initData: initDataMulticallFacet
        });
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.vault,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsVaultFacet,
            initData: initDataVaultFacet
        });
        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.uniswapV2,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsUniswapV2Facet,
            initData: initDataUniswapV2Facet
        });
        cuts[6] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.origami,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsMORELeverageFacet,
            initData: initDataMORELeverageFacet
        });
        cuts[7] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.moreMarkets,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsAaveV3Facet,
            initData: initDataAaveV3Facet
        });
        cuts[8] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.izumiSwap,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsIzumiSwapFacet,
            initData: ""
        });
        cuts[9] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.aggroKittySwap,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsAggroKittySwapFacet,
            initData: ""
        });
        cuts[10] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.curve,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsCurveFacet,
            initData: initDataCurveFacet
        });
        cuts[11] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.uniswapV3,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsUniswapV3Facet,
            initData: ""
        });
        cuts[12] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.multiRewards,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsMultiRewardsFacet,
            initData: initDataMultiRewardsFacet
        });
        cuts[13] = IDiamondCut.FacetCut({
            facetAddress: facetAddresses.curveGaugeV6,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsCurveLiquidityGaugeV6Facet,
            initData: initDataCurveLiquidityGaugeV6Facet
        });

        return cuts;
    }
}

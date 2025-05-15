// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {IOrigamiInvestment} from "../interfaces/Origami/IOrigamiInvestment.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";
import {IOrigamiLovTokenFlashAndBorrowManager} from "../interfaces/Origami/IOrigamiLovTokenFlashAndBorrowManager.sol";
import {IMORELeverageFacet} from "../interfaces/facets/IMORELeverageFacet.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error UnsupportedAsset(address);
error UnsupportedLovToken(address);

contract MORELeverageFacet is BaseFacetInitializer, IMORELeverageFacet {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 constant ORIGAMI_VAULT_TOKENS_ID =
        keccak256("ORIGAMI_VAULT_TOKENS_ID");
    uint48 constant MAX_SLIPPAGE_BPS_FOR_ACCOUNTING = 1000;

    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.MORELeverageFacet");
    }

    function facetName() external pure returns (string memory) {
        return "MORELeverageFacet";
    }

    function initialize(bytes calldata data) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address facetAddress = abi.decode(data, (address));
        ds.facetsForAccounting.push(facetAddress);
        ds.supportedInterfaces[type(IMORELeverageFacet).interfaceId] = true;
    }

    function accountingMORELeverageFacet() external view returns (uint sum) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        EnumerableSet.AddressSet storage lovTokensHeld = ds.tokensHeld[
            ORIGAMI_VAULT_TOKENS_ID
        ];
        for (uint i = 0; i < lovTokensHeld.length(); ) {
            address lovToken = lovTokensHeld.at(i);
            if (ds.isAssetAvailable[lovToken]) {
                unchecked {
                    ++i;
                }
                continue;
            }
            uint balance = IERC20(lovToken).balanceOf(address(this)) +
                ds.staked[lovToken];
            address underlyingToken = IOrigamiInvestment(lovToken).baseToken();
            (
                IOrigamiInvestment.ExitQuoteData memory quoteData,

            ) = IOrigamiInvestment(lovToken).exitQuote(
                    balance,
                    underlyingToken,
                    MAX_SLIPPAGE_BPS_FOR_ACCOUNTING,
                    block.timestamp
                );

            sum += MoreVaultsLib.convertToUnderlying(
                underlyingToken,
                quoteData.minToTokenAmount
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @inheritdoc IMORELeverageFacet
     */
    function investWithToken(
        address lovToken,
        IOrigamiInvestment.InvestQuoteData calldata quoteData
    ) external returns (uint256 investmentAmount) {
        AccessControlLib.validateDiamond(msg.sender);
        address fromToken = quoteData.fromToken;
        MoreVaultsLib.validateAssetAvailable(fromToken);
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        IERC20(fromToken).forceApprove(lovToken, quoteData.fromTokenAmount);
        investmentAmount = IOrigamiInvestment(lovToken).investWithToken(
            quoteData
        );
        ds.tokensHeld[ORIGAMI_VAULT_TOKENS_ID].add(lovToken);
    }

    /**
     * @inheritdoc IMORELeverageFacet
     */
    function investWithNative(
        address lovToken,
        IOrigamiInvestment.InvestQuoteData calldata quoteData
    ) external returns (uint256 investmentAmount) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAssetAvailable(quoteData.fromToken);
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        investmentAmount = IOrigamiInvestment(lovToken).investWithNative{
            value: quoteData.fromTokenAmount
        }(quoteData);
        ds.tokensHeld[ORIGAMI_VAULT_TOKENS_ID].add(lovToken);
    }

    /**
     * @inheritdoc IMORELeverageFacet
     */
    function exitToToken(
        address lovToken,
        IOrigamiInvestment.ExitQuoteData calldata quoteData
    ) public returns (uint256 toTokenAmount) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAssetAvailable(quoteData.toToken);

        toTokenAmount = _exitTo(lovToken, quoteData, false);
    }

    /**
     * @inheritdoc IMORELeverageFacet
     */
    function exitToNative(
        address lovToken,
        IOrigamiInvestment.ExitQuoteData calldata quoteData
    ) public returns (uint256 toTokenAmount) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAssetAvailable(address(0));

        toTokenAmount = _exitTo(lovToken, quoteData, true);
    }

    /**
     * @inheritdoc IMORELeverageFacet
     */
    function rebalanceUp(
        address manager,
        uint256 flashLoanAmount,
        uint256 collateralToWithdraw,
        bytes calldata swapData,
        uint256 repaySurplusThreshold,
        uint128 minNewAL,
        uint128 maxNewAL
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        IOrigamiLovTokenFlashAndBorrowManager.RebalanceUpParams
            memory params = IOrigamiLovTokenFlashAndBorrowManager
                .RebalanceUpParams({
                    flashLoanAmount: flashLoanAmount,
                    collateralToWithdraw: collateralToWithdraw,
                    swapData: swapData,
                    repaySurplusThreshold: repaySurplusThreshold,
                    minNewAL: minNewAL,
                    maxNewAL: maxNewAL
                });
        IOrigamiLovTokenFlashAndBorrowManager(manager).rebalanceUp(params);
    }

    /**
     * @inheritdoc IMORELeverageFacet
     */
    function forceRebalanceUp(
        address manager,
        uint256 flashLoanAmount,
        uint256 collateralToWithdraw,
        bytes calldata swapData,
        uint256 repaySurplusThreshold,
        uint128 minNewAL,
        uint128 maxNewAL
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        IOrigamiLovTokenFlashAndBorrowManager.RebalanceUpParams
            memory params = IOrigamiLovTokenFlashAndBorrowManager
                .RebalanceUpParams({
                    flashLoanAmount: flashLoanAmount,
                    collateralToWithdraw: collateralToWithdraw,
                    swapData: swapData,
                    repaySurplusThreshold: repaySurplusThreshold,
                    minNewAL: minNewAL,
                    maxNewAL: maxNewAL
                });
        IOrigamiLovTokenFlashAndBorrowManager(manager).forceRebalanceUp(params);
    }

    /**
     * @inheritdoc IMORELeverageFacet
     */
    function rebalanceDown(
        address manager,
        uint256 flashLoanAmount,
        uint256 minExpectedReserveToken,
        bytes calldata swapData,
        uint128 minNewAL,
        uint128 maxNewAL
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        IOrigamiLovTokenFlashAndBorrowManager.RebalanceDownParams
            memory params = IOrigamiLovTokenFlashAndBorrowManager
                .RebalanceDownParams({
                    flashLoanAmount: flashLoanAmount,
                    minExpectedReserveToken: minExpectedReserveToken,
                    swapData: swapData,
                    minNewAL: minNewAL,
                    maxNewAL: maxNewAL
                });
        IOrigamiLovTokenFlashAndBorrowManager(manager).rebalanceDown(params);
    }

    /**
     * @inheritdoc IMORELeverageFacet
     */
    function forceRebalanceDown(
        address manager,
        uint256 flashLoanAmount,
        uint256 minExpectedReserveToken,
        bytes calldata swapData,
        uint128 minNewAL,
        uint128 maxNewAL
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        IOrigamiLovTokenFlashAndBorrowManager.RebalanceDownParams
            memory params = IOrigamiLovTokenFlashAndBorrowManager
                .RebalanceDownParams({
                    flashLoanAmount: flashLoanAmount,
                    minExpectedReserveToken: minExpectedReserveToken,
                    swapData: swapData,
                    minNewAL: minNewAL,
                    maxNewAL: maxNewAL
                });
        IOrigamiLovTokenFlashAndBorrowManager(manager).forceRebalanceDown(
            params
        );
    }

    function _exitTo(
        address lovToken,
        IOrigamiInvestment.ExitQuoteData calldata quoteData,
        bool toNative
    ) internal returns (uint256 toTokenAmount) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        if (toNative) {
            toTokenAmount = IOrigamiInvestment(lovToken).exitToNative(
                quoteData,
                payable(address(this))
            );
        } else {
            toTokenAmount = IOrigamiInvestment(lovToken).exitToToken(
                quoteData,
                address(this)
            );
        }

        MoreVaultsLib.removeTokenIfnecessary(
            ds.tokensHeld[ORIGAMI_VAULT_TOKENS_ID],
            lovToken
        );
    }
}

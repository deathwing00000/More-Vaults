// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {IOrigamiInvestment} from "../interfaces/Origami/IOrigamiInvestment.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";
import {IOrigamiLovTokenFlashAndBorrowManager} from "../interfaces/Origami/IOrigamiLovTokenFlashAndBorrowManager.sol";
import {IOrigamiFacet} from "../interfaces/facets/IOrigamiFacet.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";

error UnsupportedAsset(address);
error UnsupportedLovToken(address);

contract OrigamiFacet is BaseFacetInitializer, IOrigamiFacet {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Math for uint256;

    bytes32 constant ORIGAMI_VAULT_TOKENS_ID =
        keccak256("ORIGAMI_VAULT_TOKENS_ID");
    uint48 constant MAX_SLIPPAGE_BPS = 1000;

    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.OrigamiFacet");
    }

    function initialize(bytes calldata data) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address facetAddress = abi.decode(data, (address));
        ds.facetsForAccounting.push(facetAddress);
        ds.supportedInterfaces[type(IOrigamiFacet).interfaceId] = true;
    }

    function facetName() external pure returns (string memory) {
        return "OrigamiFacet";
    }

    function validateDiamond() internal view returns (bool) {
        return msg.sender == address(this);
    }

    function accountingOrigamiFacet() external view returns (uint sum) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        EnumerableSet.AddressSet storage lovTokensHeld = ds.tokensHeld[
            ORIGAMI_VAULT_TOKENS_ID
        ];
        for (uint i = 0; i < lovTokensHeld.length(); ) {
            address lovToken = lovTokensHeld.at(i);
            uint balance = IERC20(lovToken).balanceOf(address(this));
            address underlyingToken = IOrigamiInvestment(lovToken).baseToken();
            (
                IOrigamiInvestment.ExitQuoteData memory quoteData,

            ) = IOrigamiInvestment(lovToken).exitQuote(
                    balance,
                    underlyingToken,
                    MAX_SLIPPAGE_BPS,
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

    function investWithToken(
        address lovToken,
        uint256 fromTokenAmount,
        address fromToken,
        uint256 maxSlippageBps,
        uint256 deadline
    ) external returns (uint256 investmentAmount) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(fromToken);
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        IERC20(fromToken).approve(lovToken, fromTokenAmount);
        (
            IOrigamiInvestment.InvestQuoteData memory quoteData,

        ) = IOrigamiInvestment(lovToken).investQuote(
                fromTokenAmount,
                fromToken,
                maxSlippageBps,
                deadline
            );
        investmentAmount = IOrigamiInvestment(lovToken).investWithToken(
            quoteData
        );
        ds.tokensHeld[ORIGAMI_VAULT_TOKENS_ID].add(lovToken);
    }

    function investWithNative(
        address lovToken,
        uint256 fromTokenAmount,
        address fromToken,
        uint256 maxSlippageBps,
        uint256 deadline
    ) external payable returns (uint256 investmentAmount) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(fromToken);
        // _validateLovToken(lovToken);
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        (
            IOrigamiInvestment.InvestQuoteData memory quoteData,

        ) = IOrigamiInvestment(lovToken).investQuote(
                fromTokenAmount,
                fromToken,
                maxSlippageBps,
                deadline
            );
        investmentAmount = IOrigamiInvestment(lovToken).investWithNative{
            value: fromTokenAmount
        }(quoteData);
        ds.tokensHeld[ORIGAMI_VAULT_TOKENS_ID].add(lovToken);
    }

    function exitToToken(
        address lovToken,
        uint256 investmentAmount,
        address toToken,
        uint256 maxSlippageBps,
        uint256 deadline
    ) public returns (uint256 toTokenAmount) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(toToken);
        // _validateLovToken(lovToken);

        toTokenAmount = _exitTo(
            lovToken,
            investmentAmount,
            toToken,
            maxSlippageBps,
            deadline,
            false
        );
    }

    function exitToNative(
        address lovToken,
        uint256 investmentAmount,
        address toToken,
        uint256 maxSlippageBps,
        uint256 deadline
    ) public returns (uint256 toTokenAmount) {
        MoreVaultsLib.validateAsset(toToken);
        // _validateLovToken(lovToken);
        AccessControlLib.validateDiamond(msg.sender);

        toTokenAmount = _exitTo(
            lovToken,
            investmentAmount,
            toToken,
            maxSlippageBps,
            deadline,
            true
        );
    }

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
        uint256 investmentAmount,
        address toToken,
        uint256 maxSlippageBps,
        uint256 deadline,
        bool toNative
    ) internal returns (uint256 toTokenAmount) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        (
            IOrigamiInvestment.ExitQuoteData memory quoteData,

        ) = IOrigamiInvestment(lovToken).exitQuote(
                investmentAmount,
                toToken,
                maxSlippageBps,
                deadline
            );
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

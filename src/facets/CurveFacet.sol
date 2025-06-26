// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MoreVaultsLib, BEFORE_ACCOUNTING_SELECTOR, BEFORE_ACCOUNTING_FAILED_ERROR} from "../libraries/MoreVaultsLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {ICurveFacet} from "../interfaces/facets/ICurveFacet.sol";
import {ICurveRouter} from "../interfaces/Curve/ICurveRouter.sol";
import {ICurveViews} from "../interfaces/Curve/ICurveViews.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ILiquidityGaugeV6} from "../interfaces/Curve/ILiquidityGaugeV6.sol";
import {IMultiRewards} from "../interfaces/Curve/IMultiRewards.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title CurveFacet
 * @notice Facet for handling token exchanges through Curve protocol
 */
contract CurveFacet is ICurveFacet, BaseFacetInitializer {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Math for uint256;

    bytes32 constant CURVE_LP_TOKENS_ID = keccak256("CURVE_LP_TOKENS_ID");
    bytes32 constant COINS_SELECTOR =
        0xc661065700000000000000000000000000000000000000000000000000000000;

    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.CurveFacet.V1.0.1");
    }

    /**
     * @notice Returns the name of the facet
     * @return The facet name
     */
    function facetName() public pure returns (string memory) {
        return "CurveFacet";
    }

    function facetVersion() public pure returns (string memory) {
        return "1.0.1";
    }

    function initialize(bytes calldata data) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.supportedInterfaces[type(ICurveFacet).interfaceId] = true;
        (address facetAddress, bytes32 facetSelector) = abi.decode(
            data,
            (address, bytes32)
        );
        ds.facetsForAccounting.push(facetSelector);
        ds.beforeAccountingFacets.push(facetAddress);
        ds.vaultExternalAssets[MoreVaultsLib.TokenType.HeldToken].add(
            CURVE_LP_TOKENS_ID
        );
    }

    function onFacetRemoval(address facetAddress, bool isReplacing) external {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.supportedInterfaces[type(ICurveFacet).interfaceId] = false;

        MoreVaultsLib.removeFromBeforeAccounting(ds, facetAddress, isReplacing);
        MoreVaultsLib.removeFromFacetsForAccounting(
            ds,
            facetAddress,
            isReplacing
        );

        if (!isReplacing) {
            ds.vaultExternalAssets[MoreVaultsLib.TokenType.HeldToken].remove(
                CURVE_LP_TOKENS_ID
            );
        }
    }

    function beforeAccounting() external {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        EnumerableSet.AddressSet storage tokensHeld = ds.tokensHeld[
            CURVE_LP_TOKENS_ID
        ];

        for (uint256 i = 0; i < tokensHeld.length(); ) {
            ICurveViews(tokensHeld.at(i)).remove_liquidity_one_coin(0, 0, 0);
            unchecked {
                ++i;
            }
        }
    }

    function accountingCurveFacet()
        public
        view
        returns (uint256 sum, bool isPositive)
    {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        EnumerableSet.AddressSet storage tokensHeld = ds.tokensHeld[
            CURVE_LP_TOKENS_ID
        ];
        for (uint256 i = 0; i < tokensHeld.length(); ) {
            address lpToken = tokensHeld.at(i);
            uint256 poolLength = ds.curvePoolLength[lpToken];
            // if the lp token is available asset, then it should be already accounted
            if (ds.isAssetAvailable[lpToken]) {
                unchecked {
                    ++i;
                }
                continue;
            }

            address gauge = ds.stakingTokenToGauge[lpToken];
            address multiReawrd = ds.stakingTokenToMultiRewards[lpToken];

            // Get direct LP token balance
            uint256 lpTokenBalance = IERC20(lpToken).balanceOf(address(this));
            if (gauge != address(0)) {
                lpTokenBalance += ILiquidityGaugeV6(gauge).balanceOf(
                    address(this)
                );
            }
            if (multiReawrd != address(0)) {
                lpTokenBalance += IMultiRewards(multiReawrd).balanceOf(
                    address(this)
                );
            }

            uint256 minPrice;
            for (uint256 j = 0; j < poolLength; ) {
                address token = ICurveViews(lpToken).coins(j);
                uint256 tokenDecimals = IERC20Metadata(token).decimals();
                uint256 price = MoreVaultsLib.convertToUnderlying(
                    token,
                    10 ** tokenDecimals,
                    Math.Rounding.Floor
                );

                if (price < minPrice || minPrice == 0) {
                    minPrice = price;
                }
                unchecked {
                    ++j;
                }
            }

            //Price per LP in terms of underlying asset with decimals of the underlying asset
            uint256 pricePerLP = minPrice.mulDiv(
                ICurveViews(lpToken).get_virtual_price(),
                1e18,
                Math.Rounding.Floor
            );

            uint8 lpDecimal = IERC20Metadata(lpToken).decimals();
            //The value of the LPs is equal to the price of a single LP times the LP balance
            sum += pricePerLP.mulDiv(
                lpTokenBalance,
                10 ** lpDecimal,
                Math.Rounding.Floor
            );

            unchecked {
                ++i;
            }
        }
        isPositive = true;
    }

    /**
     * @inheritdoc ICurveFacet
     */
    function exchangeNg(
        address curveRouter,
        address[11] calldata _route,
        uint256[4][5] calldata _swap_params,
        uint256 _amount,
        uint256 _min_dy
    ) external payable returns (uint256) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAddressWhitelisted(curveRouter);
        address inputToken = _route[0];
        (
            uint256 index,
            address outputToken
        ) = _getOutputTokenAddressAndIndexOfLastSwap(_route);

        for (uint256 i = 0; i < _swap_params.length; ) {
            if (_swap_params[i][2] == 5 || _swap_params[i][2] == 7)
                revert InvalidSwapType(i);
            unchecked {
                ++i;
            }
        }
        // If not remove liquidity - validate input token
        if (_swap_params[0][2] != 6) {
            MoreVaultsLib.validateAssetAvailable(inputToken);
        }
        // If not add liquidity - validate output token
        if (_swap_params[index][2] != 4) {
            MoreVaultsLib.validateAssetAvailable(outputToken);
        } else {
            // if add liquidity, validate, that first coin in pool is available in vault
            MoreVaultsLib.validateAssetAvailable(
                ICurveViews(outputToken).coins(0)
            );
        }
        IERC20(inputToken).forceApprove(curveRouter, _amount);
        uint256 receivedAmount = ICurveRouter(curveRouter).exchange(
            _route,
            _swap_params,
            _amount,
            _min_dy,
            address(this)
        );

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        if (_swap_params[index][2] == 4) {
            ds.tokensHeld[CURVE_LP_TOKENS_ID].add(outputToken);
            if (ds.curvePoolLength[outputToken] == 0) {
                ds.curvePoolLength[outputToken] = _getPoolLength(outputToken);
            }
        }
        if (_swap_params[0][2] == 6) {
            MoreVaultsLib.removeTokenIfnecessary(
                ds.tokensHeld[CURVE_LP_TOKENS_ID],
                inputToken
            );
        }
        return receivedAmount;
    }

    /**
     * @inheritdoc ICurveFacet
     */
    function exchange(
        address curveRouter,
        address[11] calldata _route,
        uint256[5][5] calldata _swap_params,
        uint256 _amount,
        uint256 _min_dy,
        address[5] calldata _pools
    ) external payable returns (uint256) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAddressWhitelisted(curveRouter);
        address inputToken = _route[0];
        (
            uint256 index,
            address outputToken
        ) = _getOutputTokenAddressAndIndexOfLastSwap(_route);

        for (uint256 i = 0; i < _swap_params.length; ) {
            if (_swap_params[i][2] == 5 || _swap_params[i][2] == 7)
                revert InvalidSwapType(i);
            unchecked {
                ++i;
            }
        }

        // If not remove liquidity - validate input token
        if (_swap_params[0][2] != 6) {
            MoreVaultsLib.validateAssetAvailable(inputToken);
        }
        // If not add liquidity - validate output token
        if (_swap_params[index][2] != 4) {
            MoreVaultsLib.validateAssetAvailable(outputToken);
        } else {
            // if add liquidity, validate, that first coin in pool is available in vault
            MoreVaultsLib.validateAssetAvailable(
                ICurveViews(outputToken).coins(0)
            );
        }
        IERC20(inputToken).forceApprove(curveRouter, _amount);
        uint256 receivedAmount = ICurveRouter(curveRouter).exchange(
            _route,
            _swap_params,
            _amount,
            _min_dy,
            _pools,
            address(this)
        );

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        if (_swap_params[index][2] == 4) {
            ds.tokensHeld[CURVE_LP_TOKENS_ID].add(outputToken);
            if (ds.curvePoolLength[outputToken] == 0) {
                ds.curvePoolLength[outputToken] = _getPoolLength(outputToken);
            }
        }
        if (_swap_params[0][2] == 6) {
            MoreVaultsLib.removeTokenIfnecessary(
                ds.tokensHeld[CURVE_LP_TOKENS_ID],
                inputToken
            );
        }
        return receivedAmount;
    }

    /**
     * @notice Extracts output token address from the swap path
     * @param _route The swap path containing route information
     * @return i index of last swap in the route
     * @return outputToken The address of the output token
     */
    function _getOutputTokenAddressAndIndexOfLastSwap(
        address[11] calldata _route
    ) internal pure returns (uint256 i, address outputToken) {
        while (i < 4 && _route[i * 2 + 3] != address(0)) i++;
        outputToken = _route[(i + 1) * 2];
    }

    function _getPoolLength(
        address pool
    ) internal view returns (uint256 length) {
        assembly {
            let freePtr := mload(0x40)
            mstore(freePtr, COINS_SELECTOR)
            for {
                let i := 0
            } 1 {
                i := add(i, 1)
            } {
                mstore(add(freePtr, 4), i)
                let res := staticcall(gas(), pool, freePtr, 0x24, 0, 0)
                if iszero(res) {
                    break
                }
                length := add(length, 1)
            }
        }
    }
}

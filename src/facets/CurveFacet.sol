// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {ICurveFacet} from "../interfaces/facets/ICurveFacet.sol";
import {ICurveRouter} from "../interfaces/Curve/ICurveRouter.sol";
import {ICurveViews} from "../interfaces/Curve/ICurveViews.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title CurveFacet
 * @notice Facet for handling token exchanges through Curve protocol
 */
contract CurveFacet is ICurveFacet, BaseFacetInitializer {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 constant CURVE_LP_TOKENS_ID = keccak256("CURVE_LP_TOKENS_ID");

    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.CurveFacet");
    }

    /**
     * @notice Returns the name of the facet
     * @return The facet name
     */
    function facetName() external pure returns (string memory) {
        return "CurveFacet";
    }

    function initialize(bytes calldata data) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.supportedInterfaces[type(ICurveFacet).interfaceId] = true;
        address facetAddress = abi.decode(data, (address));
        ds.facetsForAccounting.push(facetAddress);
    }

    function accountingCurveFacet() public view returns (uint sum) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        EnumerableSet.AddressSet storage tokensHeld = ds.tokensHeld[
            CURVE_LP_TOKENS_ID
        ];
        for (uint256 i = 0; i < tokensHeld.length(); ) {
            address lpToken = tokensHeld.at(i);
            // if the lp token is available asset, then it should be already accounted
            if (ds.isAssetAvailable[lpToken]) {
                continue;
            }
            uint256 lpTokenBalance = IERC20(lpToken).balanceOf(address(this)) +
                ds.staked[lpToken];
            sum += MoreVaultsLib.convertToUnderlying(
                ICurveViews(lpToken).coins(0),
                (
                    ICurveViews(lpToken).calc_withdraw_one_coin(
                        lpTokenBalance,
                        int128(0)
                    )
                )
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @inheritdoc ICurveFacet
     */
    function exchangeNg(
        address curveRouter,
        address[11] calldata _route,
        uint256[5][5] calldata _swap_params,
        uint256 _amount,
        uint256 _min_dy
    ) external payable returns (uint256) {
        AccessControlLib.validateDiamond(msg.sender);
        address[5] memory _pools;
        return
            _exchange(
                curveRouter,
                _route,
                _swap_params,
                _amount,
                _min_dy,
                _pools,
                true
            );
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
        return
            _exchange(
                curveRouter,
                _route,
                _swap_params,
                _amount,
                _min_dy,
                _pools,
                false
            );
    }

    function _exchange(
        address curveRouter,
        address[11] calldata _route,
        uint256[5][5] calldata _swap_params,
        uint256 _amount,
        uint256 _min_dy,
        address[5] memory _pools,
        bool isNgRouterOnly
    ) internal returns (uint256) {
        address inputToken = _route[0];
        (
            uint256 index,
            address outputToken
        ) = _getOutputTokenAddressAndIndexOfLastSwap(_route);

        // If not remove liquidity - validate input token
        if (_swap_params[index][2] != 6) {
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
        IERC20(inputToken).approve(curveRouter, _amount);
        uint256 receivedAmount;
        if (isNgRouterOnly) {
            receivedAmount = ICurveRouter(curveRouter).exchange(
                _route,
                _swap_params,
                _amount,
                _min_dy,
                address(this)
            );
        } else {
            receivedAmount = ICurveRouter(curveRouter).exchange(
                _route,
                _swap_params,
                _amount,
                _min_dy,
                _pools,
                address(this)
            );
        }

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        if (_swap_params[index][2] == 4) {
            ds.tokensHeld[CURVE_LP_TOKENS_ID].add(outputToken);
        } else if (_swap_params[index][2] == 6) {
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
}

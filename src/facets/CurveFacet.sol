// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {ICurveFacet} from "../interfaces/facets/ICurveFacet.sol";
import {ICurveRouter} from "../interfaces/Curve/ICurveRouter.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";
/**
 * @title CurveFacet
 * @notice Facet for handling token exchanges through Curve protocol
 */
contract CurveFacet is ICurveFacet, BaseFacetInitializer {
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

    function initialize(bytes calldata) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.supportedInterfaces[type(ICurveFacet).interfaceId] = true;
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
        address[5] calldata _pools,
        address _receiver
    ) external payable returns (uint256) {
        AccessControlLib.validateDiamond(msg.sender);
        address inputToken = _route[0];
        address outputToken = _getOutputTokenAddress(_route);
        MoreVaultsLib.validateAssetAvailable(inputToken);
        MoreVaultsLib.validateAssetAvailable(outputToken);
        IERC20(inputToken).transferFrom(msg.sender, address(this), _amount);
        IERC20(inputToken).approve(curveRouter, _amount);
        uint256 receivedAmount = ICurveRouter(curveRouter).exchange(
            _route,
            _swap_params,
            _amount,
            _min_dy,
            _pools,
            _receiver
        );
        IERC20(outputToken).transfer(_receiver, receivedAmount);
        return receivedAmount;
    }

    /**
     * @notice Extracts output token address from the swap path
     * @param _route The swap path containing route information
     * @return outputToken The address of the output token
     */
    function _getOutputTokenAddress(
        address[11] calldata _route
    ) internal pure returns (address outputToken) {
        uint256 i = 0;
        while (i < 4 || _route[i * 2 + 3] != address(0)) i++;
        return _route[(i + 1) * 2];
    }
}

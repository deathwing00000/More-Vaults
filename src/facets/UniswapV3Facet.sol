// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {Bytes} from "@openzeppelin/contracts/utils/Bytes.sol";
import {IUniswapV3Facet, ISwapRouter} from "../interfaces/facets/IUniswapV3Facet.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title UniswapV3Facet
 * @notice Facet for handling token swaps through UniV3 protocol
 * @dev Implements swap functionality with amount and desire-based single and multihop swaps
 */
contract UniswapV3Facet is IUniswapV3Facet, BaseFacetInitializer {
    using SafeERC20 for IERC20;
    using Bytes for bytes;

    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.UniswapV3Facet");
    }

    /**
     * @notice Returns the name of the facet
     * @return The facet name
     */
    function facetName() external pure returns (string memory) {
        return "UniswapV3Facet";
    }

    function initialize(bytes calldata) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.supportedInterfaces[type(IUniswapV3Facet).interfaceId] = true;
    }

    /**
     * @inheritdoc IUniswapV3Facet
     */
    function exactInputSingle(
        address router,
        ISwapRouter.ExactInputSingleParams memory params
    ) external payable returns (uint256 amountOut) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAddressWhitelisted(router);
        if (params.recipient != address(this)) {
            params.recipient = address(this);
        }
        MoreVaultsLib.validateAssetAvailable(params.tokenIn);
        MoreVaultsLib.validateAssetAvailable(params.tokenOut);

        IERC20(params.tokenIn).forceApprove(router, params.amountIn);
        amountOut = ISwapRouter(router).exactInputSingle(params);
    }

    /**
     * @inheritdoc IUniswapV3Facet
     */
    function exactInput(
        address router,
        ISwapRouter.ExactInputParams memory params
    ) external payable returns (uint256 amountOut) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAddressWhitelisted(router);
        if (params.recipient != address(this)) {
            params.recipient = address(this);
        }
        address inputToken = _getInputTokenAddress(params.path);
        address outputToken = _getOutputTokenAddress(params.path);
        MoreVaultsLib.validateAssetAvailable(inputToken);
        MoreVaultsLib.validateAssetAvailable(outputToken);

        IERC20(inputToken).forceApprove(router, params.amountIn);
        amountOut = ISwapRouter(router).exactInput(params);
    }

    /**
     * @inheritdoc IUniswapV3Facet
     */
    function exactOutputSingle(
        address router,
        ISwapRouter.ExactOutputSingleParams memory params
    ) external payable returns (uint256 amountIn) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAddressWhitelisted(router);
        if (params.recipient != address(this)) {
            params.recipient = address(this);
        }
        MoreVaultsLib.validateAssetAvailable(params.tokenIn);
        MoreVaultsLib.validateAssetAvailable(params.tokenOut);

        IERC20(params.tokenIn).forceApprove(router, params.amountInMaximum);
        amountIn = ISwapRouter(router).exactOutputSingle(params);
    }

    /**
     * @inheritdoc IUniswapV3Facet
     */
    function exactOutput(
        address router,
        ISwapRouter.ExactOutputParams memory params
    ) external payable returns (uint256 amountIn) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAddressWhitelisted(router);
        if (params.recipient != address(this)) {
            params.recipient = address(this);
        }
        address inputToken = _getInputTokenAddress(params.path);
        address outputToken = _getOutputTokenAddress(params.path);
        MoreVaultsLib.validateAssetAvailable(inputToken);
        MoreVaultsLib.validateAssetAvailable(outputToken);

        IERC20(inputToken).forceApprove(router, params.amountInMaximum);
        amountIn = ISwapRouter(router).exactOutput(params);
    }

    /**
     * @notice Extracts input token address from the swap path
     * @param path The swap path containing token addresses
     * @return inputToken The address of the input token
     * @dev Takes first 20 bytes of the path as input token address
     */
    function _getInputTokenAddress(
        bytes memory path
    ) internal pure returns (address inputToken) {
        return address(bytes20(path.slice(0, 20)));
    }

    /**
     * @notice Extracts output token address from the swap path
     * @param path The swap path containing token addresses
     * @return outputToken The address of the output token
     */
    function _getOutputTokenAddress(
        bytes memory path
    ) internal pure returns (address outputToken) {
        return address(bytes20(path.slice(path.length - 20, path.length)));
    }
}

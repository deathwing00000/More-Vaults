// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {ISwap} from "../interfaces/iZUMi/ISwap.sol";
import {Bytes} from "@openzeppelin/contracts/utils/Bytes.sol";
import {IIzumiSwapFacet} from "../interfaces/facets/IIzumiSwapFacet.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title IzumiSwapFacet
 * @notice Facet for handling token swaps through iZUMi protocol
 * @dev Implements swap functionality with amount and desire-based swaps
 */
contract IzumiSwapFacet is IIzumiSwapFacet, BaseFacetInitializer {
    using SafeERC20 for IERC20;
    using Bytes for bytes;

    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.IzumiSwapFacet");
    }

    /**
     * @notice Returns the name of the facet
     * @return The facet name
     */
    function facetName() external pure returns (string memory) {
        return "IzumiSwapFacet";
    }

    function initialize(bytes calldata) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.supportedInterfaces[type(IIzumiSwapFacet).interfaceId] = true;
    }

    /**
     * @inheritdoc IIzumiSwapFacet
     */
    function swapAmount(
        address swapContract,
        ISwap.SwapAmountParams memory params
    ) external payable returns (uint256 cost, uint256 acquire) {
        AccessControlLib.validateDiamond(msg.sender);
        address inputToken = _getInputTokenAddress(params.path);
        address outputToken = _getOutputTokenAddress(params.path);
        if (params.recipient != address(this)) {
            params.recipient = address(this);
        }
        MoreVaultsLib.validateAssetAvailable(inputToken);
        MoreVaultsLib.validateAssetAvailable(outputToken);

        IERC20(inputToken).forceApprove(swapContract, params.amount);
        (cost, acquire) = ISwap(swapContract).swapAmount(params);
    }

    /**
     * @inheritdoc IIzumiSwapFacet
     */
    function swapDesire(
        address swapContract,
        ISwap.SwapDesireParams memory params
    ) external payable returns (uint256 cost, uint256 acquire) {
        AccessControlLib.validateDiamond(msg.sender);
        address inputToken = _getInputTokenAddress(params.path);
        address outputToken = _getOutputTokenAddress(params.path);
        if (params.recipient != address(this)) {
            params.recipient = address(this);
        }
        MoreVaultsLib.validateAssetAvailable(inputToken);
        MoreVaultsLib.validateAssetAvailable(outputToken);

        IERC20(inputToken).forceApprove(swapContract, params.maxPayed);
        (cost, acquire) = ISwap(swapContract).swapDesire(params);
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

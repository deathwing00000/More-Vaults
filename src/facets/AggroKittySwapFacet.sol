// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAggroKittySwapFacet} from "../interfaces/facets/IAggroKittySwapFacet.sol";
import {IAggroKittyRouter} from "../interfaces/KittyPunch/IAggroKittyRouter.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";

contract AggroKittySwapFacet is IAggroKittySwapFacet, BaseFacetInitializer {
    using AccessControlLib for address;
    using MoreVaultsLib for address;

    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return
            keccak256("MoreVaults.storage.initializable.AggroKittySwapFacet");
    }

    function facetName() external pure returns (string memory) {
        return "AggroKittySwapFacet";
    }

    function initialize(bytes calldata) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        ds.supportedInterfaces[type(IAggroKittySwapFacet).interfaceId] = true; // AggroKittySwapFacet
    }

    function swapNoSplit(
        address _router,
        IAggroKittyRouter.Trade calldata _trade
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAssetAvailable(_trade.path[0]);
        MoreVaultsLib.validateAssetAvailable(
            _trade.path[_trade.path.length - 1]
        );

        IERC20(_trade.path[0]).approve(_router, _trade.amountIn);

        IAggroKittyRouter(_router).swapNoSplit(_trade, address(this));
    }

    function swapNoSplitFromNative(
        address _router,
        IAggroKittyRouter.Trade calldata _trade
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAssetAvailable(address(0));
        MoreVaultsLib.validateAssetAvailable(
            _trade.path[_trade.path.length - 1]
        );

        IAggroKittyRouter(_router).swapNoSplitFromNative{
            value: _trade.amountIn
        }(_trade, address(this));
    }

    function swapNoSplitToNative(
        address _router,
        IAggroKittyRouter.Trade calldata _trade
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAssetAvailable(_trade.path[0]);
        MoreVaultsLib.validateAssetAvailable(address(0));

        IERC20(_trade.path[0]).approve(_router, _trade.amountIn);

        IAggroKittyRouter(_router).swapNoSplitToNative(_trade, address(this));
    }
}

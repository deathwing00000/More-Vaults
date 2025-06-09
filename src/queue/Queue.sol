// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IVaultsFactory} from "../interfaces/IVaultsFactory.sol";
import {IVaultFacet} from "../interfaces/facets/IVaultFacet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Queue {
    using SafeERC20 for IERC20;

    event Queued(address sender, QueuedAction action);
    event RemovedFromQueue(QueuedAction action);

    enum ActionType {
        DepositUnderlying,
        Deposit,
        Mint,
        Redeem,
        Withdraw
    }

    struct QueuedAction {
        address vault;
        ActionType actionType;
        address actor;
        address receiver;
        uint256[] amounts;
        address[] assets;
    }

    mapping(address => mapping (address => QueuedAction)) public queuedActions;

    address public factory;

    constructor(
        address _factory
    ) {
        factory = _factory;
    }

    function requestDeposit(
        address vault,
        address[] calldata tokens,
        uint256[] calldata assets,
        address receiver
    ) external payable {
        for (uint i; i < assets.length; ) {
            SafeERC20.safeTransferFrom(
                IERC20(tokens[i]),
                msg.sender,
                address(this),
                assets[i]
            );
            unchecked {
                ++i;
            }
        }
        QueuedAction memory action = QueuedAction({
            vault: vault,
            actionType: ActionType.Deposit,
            sender: msg.sender,
            receiver: receiver,
            amounts: assets,
            assets: tokens
        });
    }

    function requestUnderlyingDeposit(
        address vault,
        uint256 assets,
        address receiver
    ) external {

    }

    function requestMint(
        address vault,
        uint256 shares,
        address receiver
    ) external {

    }

    function requestWithdraw(
        address vault,
        uint256 assets,
        address receiver,
        address owner
    ) external {

    }

    function requestRedeem(
        address vault,
        uint256 shares,
        address receiver,
        address owner
    ) external {

    }
}

    
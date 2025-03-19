// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IMulticallFacet} from "../interfaces/facets/IMulticallFacet.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MulticallFacet is
    IMulticallFacet,
    ContextUpgradeable,
    ReentrancyGuard
{
    uint256 constant MAX_ACTIONS_DELAY = 7 days;

    function facetName() external pure returns (string memory) {
        return "MulticallFacet";
    }

    function submitActions(
        bytes[] calldata actionsData
    ) external override returns (uint256 nonce) {
        AccessControlLib.validateCurator(msg.sender);
        require(actionsData.length > 0, "Empty actions");

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        nonce = ds.actionNonce;
        uint256 pendingUntil = block.timestamp + ds.timeLockPeriod;

        ds.pendingActions[nonce] = MoreVaultsLib.PendingActions({
            actionsData: actionsData,
            pendingUntil: pendingUntil
        });
        ds.actionNonce++;

        emit ActionsSubmitted(msg.sender, pendingUntil, actionsData);
        return nonce;
    }

    function executeActions(
        uint256 actionsNonce
    ) external override nonReentrant {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        MoreVaultsLib.PendingActions storage actions = ds.pendingActions[
            actionsNonce
        ];

        if (actions.pendingUntil == 0) {
            revert NoSuchActions(actionsNonce);
        }

        if (block.timestamp < actions.pendingUntil) {
            revert ActionsStillPending(actionsNonce);
        }

        multicall(actions.actionsData);
        delete ds.pendingActions[actionsNonce];

        emit ActionsExecuted(msg.sender, actionsNonce);
    }

    function vetoActions(uint256 actionsNonce) external override {
        AccessControlLib.validateGuardian(msg.sender);
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        if (ds.pendingActions[actionsNonce].pendingUntil == 0) {
            revert NoSuchActions(actionsNonce);
        }

        delete ds.pendingActions[actionsNonce];
        emit ActionsVetoed(msg.sender, actionsNonce);
    }

    function getPendingActions(
        uint256 actionsNonce
    )
        external
        view
        override
        returns (bytes[] memory actionsData, uint256 pendingUntil)
    {
        MoreVaultsLib.PendingActions storage actions = MoreVaultsLib
            .moreVaultsStorage()
            .pendingActions[actionsNonce];
        return (actions.actionsData, actions.pendingUntil);
    }

    function getCurrentNonce() external view override returns (uint256) {
        return MoreVaultsLib.moreVaultsStorage().actionNonce;
    }

    function multicall(
        bytes[] storage data
    ) internal virtual returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; ) {
            (bool success, bytes memory result) = address(this).call(data[i]);
            if (!success) {
                revert MulticallFailed(i, result);
            }
            results[i] = result;
            unchecked {
                ++i;
            }
        }
        return results;
    }
}

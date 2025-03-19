// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/******************************************************************************\
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

import {MoreVaultsLib} from "./libraries/MoreVaultsLib.sol";
import {AccessControlLib} from "./libraries/AccessControlLib.sol";
import {IDiamondCut} from "./interfaces/facets/IDiamondCut.sol";

contract MoreVaultsDiamond {
    constructor(
        address _diamondCutFacet,
        address _registry,
        IDiamondCut.FacetCut[] memory _cuts
    ) payable {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IDiamondCut.diamondCut.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors,
            initData: ""
        });
        AccessControlLib.AccessControlStorage storage acs = AccessControlLib
            .accessControlStorage();
        acs.moreVaultsRegistry = _registry;
        MoreVaultsLib.diamondCut(cut);

        MoreVaultsLib.diamondCut(_cuts);
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        MoreVaultsLib.MoreVaultsStorage storage ds;
        bytes32 position = MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }
        // get facet from function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Diamond: Function does not exist");
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AccessControlLib} from "./AccessControlLib.sol";
import {IDiamondCut} from "../interfaces/facets/IDiamondCut.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IAaveOracle} from "@aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";
import {IAggregatorV2V3Interface} from "../interfaces/Chainlink/IAggregatorV2V3Interface.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IGenericMoreVaultFacetInitializable} from "../interfaces/facets/IGenericMoreVaultFacetInitializable.sol";

library MoreVaultsLib {
    error InitializationFunctionReverted(
        address _initializationContractAddress,
        bytes _calldata
    );
    error UnsupportedAsset(address);
    error FacetNotAllowed(address facet);
    error InvalidSelectorForFacet(bytes4 selector, address facet);
    error IncorrectFacetCutAction(uint8 action);

    using EnumerableSet for EnumerableSet.AddressSet;
    using Math for uint256;

    // 32 bytes keccak hash of a string to use as a diamond storage location.
    bytes32 constant MORE_VAULTS_STORAGE_POSITION =
        keccak256("MoreVaults.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    struct PendingActions {
        bytes[] actionsData;
        uint256 pendingUntil;
    }

    struct MoreVaultsStorage {
        // maps function selector to the facet address and
        // the position of the selector in the facetFunctionSelectors.selectors array
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // facet addresses
        address[] facetAddresses;
        address[] facetsForAccounting;
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
        mapping(address => bool) isAssetAvailable;
        address[] availableAssets;
        mapping(bytes32 => EnumerableSet.AddressSet) tokensHeld;
        address morePoolAddressesProviderRegistry; // TODO: remove this prob
        address underlyingToken;
        address wrappedNative;
        address feeRecipient;
        uint256 lastTotalAssets; // TODO: remove this prob, try to optimize accounting
        uint96 fee;
        uint256 actionNonce;
        mapping(uint256 => PendingActions) pendingActions;
        uint256 timeLockPeriod;
    }

    function moreVaultsStorage()
        internal
        pure
        returns (MoreVaultsStorage storage ds)
    {
        bytes32 position = MORE_VAULTS_STORAGE_POSITION;
        // assigns struct storage slot to the storage position
        assembly {
            ds.slot := position
        }
    }

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut);

    function validateAsset(address asset) internal view {
        MoreVaultsStorage storage ds = moreVaultsStorage();
        if (!ds.isAssetAvailable[asset]) revert UnsupportedAsset(asset);
    }

    function removeTokenIfnecessary(
        EnumerableSet.AddressSet storage tokensHeld,
        address token
    ) internal {
        if (IERC20(token).balanceOf(address(this)) < 10e3) {
            tokensHeld.remove(token);
        }
    }

    function convertToUnderlying(
        address _token,
        uint amount
    ) internal view returns (uint) {
        MoreVaultsStorage storage ds = moreVaultsStorage();
        AccessControlLib.AccessControlStorage storage acs = AccessControlLib
            .accessControlStorage();

        if (_token == address(0)) {
            _token = address(ds.wrappedNative);
        }
        IMoreVaultsRegistry registry = IMoreVaultsRegistry(
            acs.moreVaultsRegistry
        );
        IAaveOracle oracle = registry.oracle();
        address oracleDenominationAsset = registry.getDenominationAsset();
        uint8 denominationAssetDecimals = IERC20Metadata(
            oracleDenominationAsset
        ).decimals();

        IAggregatorV2V3Interface aggregator = IAggregatorV2V3Interface(
            oracle.getSourceOfAsset(_token)
        );
        uint256 inputTokenPrice = uint256(aggregator.latestAnswer());
        uint8 inputTokenOracleDecimals = aggregator.decimals();

        inputTokenPrice = _convertToCorrectDecimals(
            denominationAssetDecimals,
            inputTokenOracleDecimals,
            inputTokenPrice
        );
        address underlyingToken = ds.underlyingToken;
        if (underlyingToken != oracleDenominationAsset) {
            aggregator = IAggregatorV2V3Interface(
                oracle.getSourceOfAsset(underlyingToken)
            );
            uint256 underlyingTokenPrice = uint256(aggregator.latestAnswer());
            uint8 underlyingTokenOracleDecimals = aggregator.decimals();
            underlyingTokenPrice = _convertToCorrectDecimals(
                denominationAssetDecimals,
                underlyingTokenOracleDecimals,
                underlyingTokenPrice
            );
            uint256 inputToUnderlyingPrice = inputTokenPrice.mulDiv(
                10 ** underlyingTokenOracleDecimals,
                underlyingTokenPrice
            );
            return
                amount.mulDiv(
                    inputToUnderlyingPrice,
                    10 ** inputTokenOracleDecimals
                );
        } else {
            return
                amount.mulDiv(inputTokenPrice, 10 ** inputTokenOracleDecimals);
        }
    }

    function _convertToCorrectDecimals(
        uint256 tokenDecimals,
        uint256 priceDecimals,
        uint256 price
    ) internal pure returns (uint256) {
        if (tokenDecimals > priceDecimals) {
            return price * 10 ** (tokenDecimals - priceDecimals);
        } else {
            return price / 10 ** (priceDecimals - tokenDecimals);
        }
    }

    // Internal function version of diamondCut
    function diamondCut(IDiamondCut.FacetCut[] memory _diamondCut) internal {
        AccessControlLib.AccessControlStorage storage acs = AccessControlLib
            .accessControlStorage();
        IMoreVaultsRegistry registry = IMoreVaultsRegistry(
            acs.moreVaultsRegistry
        );

        for (uint256 facetIndex; facetIndex < _diamondCut.length; ) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            address facetAddress = _diamondCut[facetIndex].facetAddress;
            bytes4[] memory functionSelectors = _diamondCut[facetIndex]
                .functionSelectors;

            // Validate facet and selectors for Add and Replace actions
            if (
                action == IDiamondCut.FacetCutAction.Add ||
                action == IDiamondCut.FacetCutAction.Replace
            ) {
                // Check if facet is allowed in registry
                bool isAllowed = registry.isFacetAllowed(facetAddress);
                if (!isAllowed) {
                    revert FacetNotAllowed(facetAddress);
                }

                // Verify all selectors belong to this facet
                for (uint256 j = 0; j < functionSelectors.length; ) {
                    address selectorToFacet = registry.selectorToFacet(
                        functionSelectors[j]
                    );
                    if (selectorToFacet != facetAddress) {
                        revert InvalidSelectorForFacet(
                            functionSelectors[j],
                            facetAddress
                        );
                    }
                    unchecked {
                        ++j;
                    }
                }
            }

            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else {
                revert IncorrectFacetCutAction(uint8(action));
            }
            if (
                action == IDiamondCut.FacetCutAction.Add &&
                _diamondCut[facetIndex].initData.length > 0
            ) {
                initializeAfterAddition(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].initData
                );
            }
            unchecked {
                ++facetIndex;
            }
        }
        emit DiamondCut(_diamondCut);
    }

    function addFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(
            _functionSelectors.length > 0,
            "MoreVaultsLibCut: No selectors in facet to cut"
        );
        MoreVaultsStorage storage ds = moreVaultsStorage();
        require(
            _facetAddress != address(0),
            "MoreVaultsLibCut: Add facet can't be address(0)"
        );
        uint96 selectorPosition = uint96(
            ds.facetFunctionSelectors[_facetAddress].functionSelectors.length
        );
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for (
            uint256 selectorIndex;
            selectorIndex < _functionSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds
                .selectorToFacetAndPosition[selector]
                .facetAddress;
            require(
                oldFacetAddress == address(0),
                "MoreVaultsLibCut: Can't add function that already exists"
            );
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function replaceFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(
            _functionSelectors.length > 0,
            "MoreVaultsLibCut: No selectors in facet to cut"
        );
        MoreVaultsStorage storage ds = moreVaultsStorage();
        require(
            _facetAddress != address(0),
            "MoreVaultsLibCut: Add facet can't be address(0)"
        );
        uint96 selectorPosition = uint96(
            ds.facetFunctionSelectors[_facetAddress].functionSelectors.length
        );
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for (
            uint256 selectorIndex;
            selectorIndex < _functionSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds
                .selectorToFacetAndPosition[selector]
                .facetAddress;
            require(
                oldFacetAddress != _facetAddress,
                "MoreVaultsLibCut: Can't replace function with same function"
            );
            removeFunction(ds, oldFacetAddress, selector);
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function removeFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(
            _functionSelectors.length > 0,
            "MoreVaultsLibCut: No selectors in facet to cut"
        );
        MoreVaultsStorage storage ds = moreVaultsStorage();
        // if function does not exist then do nothing and return
        require(
            _facetAddress == address(0),
            "MoreVaultsLibCut: Remove facet address must be address(0)"
        );
        for (
            uint256 selectorIndex;
            selectorIndex < _functionSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds
                .selectorToFacetAndPosition[selector]
                .facetAddress;
            removeFunction(ds, oldFacetAddress, selector);
        }
    }

    function addFacet(
        MoreVaultsStorage storage ds,
        address _facetAddress
    ) internal {
        enforceHasContractCode(
            _facetAddress,
            "MoreVaultsLibCut: New facet has no code"
        );
        ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = ds
            .facetAddresses
            .length;
        ds.facetAddresses.push(_facetAddress);
    }

    function addFunction(
        MoreVaultsStorage storage ds,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _facetAddress
    ) internal {
        ds
            .selectorToFacetAndPosition[_selector]
            .functionSelectorPosition = _selectorPosition;
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(
            _selector
        );
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(
        MoreVaultsStorage storage ds,
        address _facetAddress,
        bytes4 _selector
    ) internal {
        require(
            _facetAddress != address(0),
            "MoreVaultsLibCut: Can't remove function that doesn't exist"
        );
        // an immutable function is a function defined directly in a diamond
        require(
            _facetAddress != address(this),
            "MoreVaultsLibCut: Can't remove immutable function"
        );
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = ds
            .selectorToFacetAndPosition[_selector]
            .functionSelectorPosition;
        uint256 lastSelectorPosition = ds
            .facetFunctionSelectors[_facetAddress]
            .functionSelectors
            .length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds
                .facetFunctionSelectors[_facetAddress]
                .functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[
                selectorPosition
            ] = lastSelector;
            ds
                .selectorToFacetAndPosition[lastSelector]
                .functionSelectorPosition = uint96(selectorPosition);
        }
        // delete the last selector
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = ds
                .facetFunctionSelectors[_facetAddress]
                .facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[
                    lastFacetAddressPosition
                ];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds
                    .facetFunctionSelectors[lastFacetAddress]
                    .facetAddressPosition = facetAddressPosition;
            }
            ds.facetAddresses.pop();
            delete ds
                .facetFunctionSelectors[_facetAddress]
                .facetAddressPosition;
        }
    }

    function initializeAfterAddition(
        address _facetAddress,
        bytes memory _initData
    ) internal {
        enforceHasContractCode(
            _facetAddress,
            "MoreVaultsLibCut: _facetAddress has no code"
        );

        bytes memory callData = abi.encodeWithSelector(
            IGenericMoreVaultFacetInitializable.initialize.selector,
            _initData
        );
        (bool success, bytes memory error) = _facetAddress.delegatecall(
            callData
        );
        if (!success) {
            if (error.length > 0) {
                // bubble up error
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert InitializationFunctionReverted(_facetAddress, callData);
            }
        }
    }

    function enforceHasContractCode(
        address _contract,
        string memory _errorMessage
    ) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}

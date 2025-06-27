// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Test.sol";
import {MoreVaultsLib} from "../../src/libraries/MoreVaultsLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

library MoreVaultsStorageHelper {
    Vm constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // Storage positions
    uint256 constant SELECTOR_TO_FACET_AND_POSITION = 0;
    uint256 constant FACET_FUNCTION_SELECTORS = 1;
    uint256 constant FACET_ADDRESSES = 2;
    uint256 constant FACETS_FOR_ACCOUNTING = 3;
    uint256 constant SUPPORTED_INTERFACE = 4;
    uint256 constant ASSET_AVAILABLE = 5;
    uint256 constant AVAILABLE_ASSETS = 6;
    uint256 constant ASSET_DEPOSITABLE = 7;
    uint256 constant TOKENS_HELD = 8;
    uint256 constant WRAPPED_NATIVE = 9;
    uint256 constant FEE_RECIPIENT = 10;
    uint256 constant FEE = 10;
    uint256 constant DEPOSIT_CAPACITY = 11;
    uint256 constant LAST_TOTAL_ASSETS = 12;
    uint256 constant ACTION_NONCE = 13;
    uint256 constant PENDING_ACTION = 14;
    uint256 constant TIME_LOCK_PERIOD = 15;
    uint256 constant STAKING_ADDRESSES = 16;
    uint256 constant STAKED = 17;
    uint256 constant MINTER = 18;
    uint256 constant IS_NATIVE_DEPOSIT = 18;
    uint256 constant BEFORE_ACCOUNTING_FACET = 19;
    uint256 constant STAKING_TOKEN_TO_GAUGE = 20;
    uint256 constant STAKING_TOKEN_TO_MULTI_REWARDS = 21;
    uint256 constant GAS_LIMIT = 22;
    uint256 constant VAULT_EXTERNAL_ASSETS = 24;
    uint256 constant TIMELOCK_DURATION = 25;
    uint256 constant WITHDRAWABLE_REQUESTS = 26;
    uint256 constant MAX_SLIPPAGE_PERCENT = 27;
    uint256 constant IS_MULTICALL = 28;
    uint256 constant FACTORY = 28;
    uint256 constant CURVE_POOL_LENGTH = 29;
    uint256 constant IS_NECESSARY_TO_CHECK_LOCK = 30;

    uint256 constant OWNER = 0;
    uint256 constant CURATOR = 1;
    uint256 constant GUARDIAN = 2;
    uint256 constant MORE_VAULTS_REGISTRY = 3;
    uint256 constant PENDING_OWNER = 4;

    bytes32 constant ACS_POSITION =
        keccak256("MoreVaults.accessControl.storage");

    // function to exclude from coverage
    function test() external {}

    function setStorageValue(
        address contractAddress,
        uint256 offset,
        bytes32 value
    ) internal {
        vm.store(
            contractAddress,
            bytes32(
                uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) + offset
            ),
            value
        );
    }

    function getStorageValue(
        address contractAddress,
        uint256 offset
    ) internal view returns (bytes32) {
        return
            vm.load(
                contractAddress,
                bytes32(
                    uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) + offset
                )
            );
    }

    function setStorageAddress(
        address contractAddress,
        uint256 offset,
        address value
    ) internal {
        setStorageValue(
            contractAddress,
            offset,
            bytes32(uint256(uint160(value)))
        );
    }

    function getStorageAddress(
        address contractAddress,
        uint256 offset
    ) internal view returns (address) {
        return
            address(uint160(uint256(getStorageValue(contractAddress, offset))));
    }

    function setArrayLength(
        address contractAddress,
        uint256 offset,
        uint256 length
    ) internal {
        setStorageValue(contractAddress, offset, bytes32(length));
    }

    function getArrayLength(
        address contractAddress,
        uint256 offset
    ) internal view returns (uint256) {
        return uint256(getStorageValue(contractAddress, offset));
    }

    function setArrayElement(
        address contractAddress,
        uint256 offset,
        uint256 index,
        bytes32 value
    ) internal {
        bytes32 arraySlot = keccak256(
            abi.encode(
                uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) + offset
            )
        );
        vm.store(contractAddress, bytes32(uint256(arraySlot) + index), value);
    }

    function getArrayElement(
        address contractAddress,
        uint256 offset,
        uint256 index
    ) internal view returns (bytes32) {
        bytes32 arraySlot = keccak256(
            abi.encode(
                uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) + offset
            )
        );
        return vm.load(contractAddress, bytes32(uint256(arraySlot) + index));
    }

    function setMappingValue(
        address contractAddress,
        uint256 offset,
        bytes32 key,
        bytes32 value
    ) internal {
        bytes32 mappingSlot = keccak256(
            abi.encode(
                key,
                bytes32(
                    uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) + offset
                )
            )
        );
        vm.store(contractAddress, mappingSlot, value);
    }

    function getMappingValue(
        address contractAddress,
        uint256 offset,
        bytes32 key
    ) internal view returns (bytes32) {
        bytes32 mappingSlot = keccak256(
            abi.encode(
                key,
                bytes32(
                    uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) + offset
                )
            )
        );
        return vm.load(contractAddress, mappingSlot);
    }

    function setSelectorToFacetAndPosition(
        address contractAddress,
        bytes4 selector,
        address facet,
        uint96 position
    ) internal {
        bytes32 mappingSlot = keccak256(
            abi.encode(
                bytes32(selector),
                bytes32(
                    uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) +
                        SELECTOR_TO_FACET_AND_POSITION
                )
            )
        );

        vm.store(
            contractAddress,
            mappingSlot,
            bytes32((uint256(uint160(facet))) | uint256(position << 216))
        );
    }

    function setFacetFunctionSelectors(
        address contractAddress,
        address facet,
        bytes4[] memory selectors,
        uint96 position
    ) internal {
        bytes32 mappingSlot = keccak256(
            abi.encode(
                facet,
                bytes32(
                    uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) +
                        FACET_FUNCTION_SELECTORS
                )
            )
        );

        vm.store(contractAddress, mappingSlot, bytes32(selectors.length));

        bytes32 arraySlot = keccak256(abi.encode(mappingSlot));
        for (uint256 i = 0; i < selectors.length; ) {
            uint256 slotIndex = i / 8;
            uint256 bitOffset = 256 - ((i + 1) % 8) * 32;
            bytes32 slot = bytes32(uint256(arraySlot) + slotIndex);
            bytes32 currentValue = vm.load(contractAddress, slot);
            bytes32 mask = bytes32(uint256(0xffffffff) >> bitOffset);
            bytes32 newValue = (currentValue & ~mask) |
                (bytes32(selectors[i]) >> bitOffset);
            vm.store(contractAddress, slot, newValue);
            unchecked {
                ++i;
            }
        }

        vm.store(
            contractAddress,
            bytes32(uint256(mappingSlot) + 1),
            bytes32(uint256(position))
        );
    }

    function setFacetAddresses(
        address contractAddress,
        address[] memory facets
    ) internal {
        setArrayLength(contractAddress, FACET_ADDRESSES, facets.length);
        for (uint256 i = 0; i < facets.length; ) {
            setArrayElement(
                contractAddress,
                FACET_ADDRESSES,
                i,
                bytes32(uint256(uint160(facets[i])))
            );
            unchecked {
                ++i;
            }
        }
    }

    function setFacetsForAccounting(
        address contractAddress,
        address[] memory facets
    ) internal {
        setArrayLength(contractAddress, FACETS_FOR_ACCOUNTING, facets.length);
        for (uint256 i = 0; i < facets.length; ) {
            setArrayElement(
                contractAddress,
                FACETS_FOR_ACCOUNTING,
                i,
                bytes32(uint256(uint160(facets[i])))
            );
            unchecked {
                ++i;
            }
        }
    }

    function getFacetsForAccounting(
        address contractAddress
    ) internal view returns (bytes32[] memory) {
        uint256 length = getArrayLength(contractAddress, FACETS_FOR_ACCOUNTING);
        bytes32[] memory facets = new bytes32[](length);
        for (uint256 i = 0; i < length; ) {
            facets[i] = getArrayElement(
                contractAddress,
                FACETS_FOR_ACCOUNTING,
                i
            );
            unchecked {
                ++i;
            }
        }
        return facets;
    }

    function setSupportedInterface(
        address contractAddress,
        bytes4 interfaceId,
        bool supported
    ) internal {
        setMappingValue(
            contractAddress,
            SUPPORTED_INTERFACE,
            bytes32(interfaceId),
            bytes32(uint256(supported ? 1 : 0))
        );
    }

    function setIsMulticall(
        address contractAddress,
        bool isMulticall
    ) internal {
        bytes32 storedValue = getStorageValue(contractAddress, IS_MULTICALL);
        bytes32 mask = bytes32(uint256(type(uint160).max) << 161);
        setStorageValue(
            contractAddress,
            IS_MULTICALL,
            (storedValue & ~mask) |
                bytes32(bytes32(uint256(isMulticall ? 1 : 0)))
        );
    }

    function setFactory(address contractAddress, address factory) internal {
        bytes32 storedValue = getStorageValue(contractAddress, FACTORY);
        bytes32 mask = bytes32(type(uint256).max << 1);
        setStorageValue(
            contractAddress,
            FACTORY,
            (storedValue & ~mask) | bytes32(uint256(uint160(factory)) << 8)
        );
    }

    function setAvailableAssets(
        address contractAddress,
        address[] memory assets
    ) internal {
        setArrayLength(contractAddress, AVAILABLE_ASSETS, assets.length);
        for (uint256 i = 0; i < assets.length; ) {
            address asset = assets[i];
            setArrayElement(
                contractAddress,
                AVAILABLE_ASSETS,
                i,
                bytes32(uint256(uint160(asset)))
            );
            setMappingValue(
                contractAddress,
                ASSET_AVAILABLE,
                bytes32(uint256(uint160(asset))),
                bytes32(uint256(1))
            );
            unchecked {
                ++i;
            }
        }
    }

    function setDepositableAssets(
        address contractAddress,
        address asset,
        bool depositable
    ) internal {
        setMappingValue(
            contractAddress,
            ASSET_DEPOSITABLE,
            bytes32(uint256(uint160(asset))),
            bytes32(uint256(depositable ? 1 : 0))
        );
    }

    function setTokensHeld(
        address contractAddress,
        bytes32 key,
        address[] memory tokens
    ) internal {
        bytes32 mappingSlot = keccak256(
            abi.encode(
                key,
                bytes32(
                    uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) +
                        TOKENS_HELD
                )
            )
        );

        // EnumerableSet stores:
        // 1. _values (address[])
        // 2. _positions (mapping(address => uint256))

        vm.store(contractAddress, mappingSlot, bytes32(tokens.length));

        bytes32 valuesSlot = keccak256(abi.encode(mappingSlot));
        for (uint256 i = 0; i < tokens.length; ) {
            vm.store(
                contractAddress,
                bytes32(uint256(valuesSlot) + i),
                bytes32(uint256(uint160(tokens[i])))
            );
            unchecked {
                ++i;
            }
        }

        bytes32 positionsSlot = bytes32(uint256(mappingSlot) + 1);
        for (uint256 i = 0; i < tokens.length; ) {
            bytes32 positionSlot = keccak256(
                abi.encode(bytes32(uint256(uint160(tokens[i]))), positionsSlot)
            );
            vm.store(contractAddress, positionSlot, bytes32(i + 1));
            unchecked {
                ++i;
            }
        }
    }

    function getTokensHeld(
        address contractAddress,
        bytes32 key
    ) internal view returns (address[] memory) {
        bytes32 mappingSlot = keccak256(
            abi.encode(
                key,
                bytes32(
                    uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) +
                        TOKENS_HELD
                )
            )
        );

        uint256 length = uint256(vm.load(contractAddress, mappingSlot));
        address[] memory tokens = new address[](length);

        bytes32 valuesSlot = keccak256(abi.encode(mappingSlot));
        for (uint256 i = 0; i < length; ) {
            tokens[i] = address(
                uint160(
                    uint256(
                        vm.load(
                            contractAddress,
                            bytes32(uint256(valuesSlot) + i)
                        )
                    )
                )
            );
            unchecked {
                ++i;
            }
        }

        return tokens;
    }

    function getStakingsEntered(
        address contractAddress,
        bytes32 key
    ) internal view returns (address[] memory) {
        bytes32 mappingSlot = keccak256(
            abi.encode(
                key,
                bytes32(
                    uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) +
                        STAKING_ADDRESSES
                )
            )
        );

        uint256 length = uint256(vm.load(contractAddress, mappingSlot));
        address[] memory stakings = new address[](length);

        bytes32 valuesSlot = keccak256(abi.encode(mappingSlot));
        for (uint256 i = 0; i < length; ) {
            stakings[i] = address(
                uint160(
                    uint256(
                        vm.load(
                            contractAddress,
                            bytes32(uint256(valuesSlot) + i)
                        )
                    )
                )
            );
            unchecked {
                ++i;
            }
        }

        return stakings;
    }

    function setWrappedNative(
        address contractAddress,
        address wrapped
    ) internal {
        setStorageAddress(contractAddress, WRAPPED_NATIVE, wrapped);
    }

    function setFeeRecipient(
        address contractAddress,
        address recipient
    ) internal {
        bytes32 storedValue = getStorageValue(contractAddress, FEE);
        bytes32 mask = bytes32(uint256(type(uint160).max));
        setStorageValue(
            contractAddress,
            FEE_RECIPIENT,
            (storedValue & ~mask) | bytes32(uint256(uint160(recipient)))
        );
    }

    function setFee(address contractAddress, uint256 value) internal {
        bytes32 storedValue = getStorageValue(contractAddress, FEE);
        bytes32 mask = bytes32(uint256(type(uint96).max) << 160);
        setStorageValue(
            contractAddress,
            FEE,
            (storedValue & ~mask) | bytes32(uint256(uint96(value)) << 160)
        );
    }

    function setDepositCapacity(
        address contractAddress,
        uint256 value
    ) internal {
        setStorageValue(contractAddress, DEPOSIT_CAPACITY, bytes32(value));
    }

    function setLastTotalAssets(
        address contractAddress,
        uint256 value
    ) internal {
        setStorageValue(contractAddress, LAST_TOTAL_ASSETS, bytes32(value));
    }

    function setActionNonce(address contractAddress, uint256 value) internal {
        setStorageValue(contractAddress, ACTION_NONCE, bytes32(value));
    }

    function setTimeLockPeriod(
        address contractAddress,
        uint256 value
    ) internal {
        setStorageValue(contractAddress, TIME_LOCK_PERIOD, bytes32(value));
    }

    function setPendingActions(
        address contractAddress,
        uint256 key,
        bytes[] memory actionsData,
        uint256 pendingUntil
    ) internal {
        bytes32 mappingSlot = keccak256(
            abi.encode(
                key,
                bytes32(
                    uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) +
                        PENDING_ACTION
                )
            )
        );

        vm.store(contractAddress, mappingSlot, bytes32(actionsData.length));

        bytes32 arraySlot = keccak256(abi.encode(mappingSlot));
        for (uint256 i = 0; i < actionsData.length; ) {
            vm.store(
                contractAddress,
                bytes32(uint256(arraySlot) + i),
                keccak256(actionsData[i])
            );
            unchecked {
                ++i;
            }
        }

        vm.store(
            contractAddress,
            bytes32(uint256(mappingSlot) + 1),
            bytes32(pendingUntil)
        );
    }

    function getFeeRecipient(
        address contractAddress
    ) internal view returns (address) {
        bytes32 storedValue = getStorageValue(contractAddress, FEE_RECIPIENT);
        bytes32 mask = bytes32(uint256(type(uint160).max));
        return address(uint160(uint256(storedValue & mask)));
    }

    function getFee(address contractAddress) internal view returns (uint96) {
        bytes32 storedValue = getStorageValue(contractAddress, FEE);
        bytes32 mask = bytes32(uint256(type(uint96).max) << 160);
        return uint96(uint256((storedValue & mask) >> 160));
    }

    function getTimeLockPeriod(
        address contractAddress
    ) internal view returns (uint256) {
        return uint256(getStorageValue(contractAddress, TIME_LOCK_PERIOD));
    }

    function isAssetAvailable(
        address contractAddress,
        address asset
    ) internal view returns (bool) {
        return
            uint256(
                getMappingValue(
                    contractAddress,
                    ASSET_AVAILABLE,
                    bytes32(uint256(uint160(asset)))
                )
            ) != 0;
    }

    function isAssetDepositable(
        address contractAddress,
        address asset
    ) internal view returns (bool) {
        return
            uint256(
                getMappingValue(
                    contractAddress,
                    ASSET_DEPOSITABLE,
                    bytes32(uint256(uint160(asset)))
                )
            ) != 0;
    }

    function getAvailableAssets(
        address contractAddress
    ) internal view returns (address[] memory) {
        uint256 length = getArrayLength(contractAddress, AVAILABLE_ASSETS);
        address[] memory assets = new address[](length);
        for (uint256 i = 0; i < length; ) {
            assets[i] = address(
                uint160(
                    uint256(
                        getArrayElement(contractAddress, AVAILABLE_ASSETS, i)
                    )
                )
            );
            unchecked {
                ++i;
            }
        }
        return assets;
    }

    function getDepositCapacity(
        address contractAddress
    ) internal view returns (uint256) {
        return uint256(getStorageValue(contractAddress, DEPOSIT_CAPACITY));
    }

    function setOwner(address contractAddress, address owner) internal {
        vm.store(
            contractAddress,
            bytes32(uint256(ACS_POSITION) + OWNER),
            bytes32(uint256(uint160(owner)))
        );
    }

    function setPendingOwner(
        address contractAddress,
        address pendingOwner
    ) internal {
        vm.store(
            contractAddress,
            bytes32(uint256(ACS_POSITION) + PENDING_OWNER),
            bytes32(uint256(uint160(pendingOwner)))
        );
    }

    function getOwner(address contractAddress) internal view returns (address) {
        return
            address(
                uint160(
                    uint256(
                        vm.load(
                            contractAddress,
                            bytes32(uint256(ACS_POSITION) + OWNER)
                        )
                    )
                )
            );
    }

    function getPendingOwner(
        address contractAddress
    ) internal view returns (address) {
        return
            address(
                uint160(
                    uint256(
                        vm.load(
                            contractAddress,
                            bytes32(uint256(ACS_POSITION) + PENDING_OWNER)
                        )
                    )
                )
            );
    }

    function setCurator(address contractAddress, address curator) internal {
        vm.store(
            contractAddress,
            bytes32(uint256(ACS_POSITION) + CURATOR),
            bytes32(uint256(uint160(curator)))
        );
    }

    function getCurator(
        address contractAddress
    ) internal view returns (address) {
        return
            address(
                uint160(
                    uint256(
                        vm.load(
                            contractAddress,
                            bytes32(uint256(ACS_POSITION) + CURATOR)
                        )
                    )
                )
            );
    }

    function setGuardian(address contractAddress, address guardian) internal {
        vm.store(
            contractAddress,
            bytes32(uint256(ACS_POSITION) + GUARDIAN),
            bytes32(uint256(uint160(guardian)))
        );
    }

    function getGuardian(
        address contractAddress
    ) internal view returns (address) {
        return
            address(
                uint160(
                    uint256(
                        vm.load(
                            contractAddress,
                            bytes32(uint256(ACS_POSITION) + GUARDIAN)
                        )
                    )
                )
            );
    }

    function setMoreVaultsRegistry(
        address contractAddress,
        address registry
    ) internal {
        vm.store(
            contractAddress,
            bytes32(uint256(ACS_POSITION) + MORE_VAULTS_REGISTRY),
            bytes32(uint256(uint160(registry)))
        );
    }

    function getMoreVaultsRegistry(
        address contractAddress
    ) internal view returns (address) {
        return
            address(
                uint160(
                    uint256(
                        vm.load(
                            contractAddress,
                            bytes32(
                                uint256(ACS_POSITION) + MORE_VAULTS_REGISTRY
                            )
                        )
                    )
                )
            );
    }

    function setVaultAsset(
        address contractAddress,
        address asset,
        uint8 decimals
    ) internal {
        MoreVaultsLib.ERC4626Storage memory data = MoreVaultsLib.ERC4626Storage(
            IERC20(asset),
            decimals
        );

        vm.store(
            contractAddress,
            MoreVaultsLib.ERC4626StorageLocation,
            bytes32(abi.encode(data))
        );
    }

    function setStaked(
        address contractAddress,
        address stakedToken,
        uint256 amount
    ) internal {
        setMappingValue(
            contractAddress,
            STAKED,
            bytes32(uint256(uint160(stakedToken))),
            bytes32(amount)
        );
    }

    function getFacetFunctionSelectors(
        address contractAddress,
        address facet
    ) internal view returns (bytes4[] memory) {
        bytes32 mappingSlot = keccak256(
            abi.encode(
                facet,
                bytes32(
                    uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) +
                        FACET_FUNCTION_SELECTORS
                )
            )
        );

        uint256 selectorsLength = uint256(
            vm.load(contractAddress, mappingSlot)
        );
        bytes4[] memory selectors = new bytes4[](selectorsLength);

        bytes32 arraySlot = keccak256(abi.encode(mappingSlot));
        for (uint256 i = 0; i < selectorsLength; ) {
            uint256 slotIndex = i / 8;
            uint256 bitOffset = 256 - ((i + 1) % 8) * 32;
            bytes32 slot = bytes32(uint256(arraySlot) + slotIndex);
            bytes32 value = vm.load(contractAddress, slot);
            bytes32 mask = bytes32(uint256(0xffffffff));
            selectors[i] = bytes4((value | ~mask) << bitOffset);
            unchecked {
                ++i;
            }
        }

        return selectors;
    }

    function getFacetAddresses(
        address contractAddress
    ) internal view returns (address[] memory) {
        uint256 length = getArrayLength(contractAddress, FACET_ADDRESSES);
        address[] memory facets = new address[](length);

        for (uint256 i = 0; i < length; ) {
            bytes32 value = getArrayElement(
                contractAddress,
                FACET_ADDRESSES,
                i
            );
            facets[i] = address(uint160(uint256(value)));
            unchecked {
                ++i;
            }
        }

        return facets;
    }

    function getFacetPosition(
        address contractAddress,
        address facet
    ) internal view returns (uint96) {
        bytes32 mappingSlot = keccak256(
            abi.encode(
                facet,
                bytes32(
                    uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) +
                        FACET_FUNCTION_SELECTORS
                )
            )
        );

        return
            uint96(
                uint256(
                    vm.load(contractAddress, bytes32(uint256(mappingSlot) + 1))
                )
            );
    }

    function getFacetBySelector(
        address contractAddress,
        bytes4 selector
    ) internal view returns (address) {
        bytes32 mappingSlot = keccak256(
            abi.encode(
                bytes32(selector),
                bytes32(
                    uint256(MoreVaultsLib.MORE_VAULTS_STORAGE_POSITION) +
                        SELECTOR_TO_FACET_AND_POSITION
                )
            )
        );
        return address(uint160(uint256(vm.load(contractAddress, mappingSlot))));
    }

    function getSupportedInterface(
        address contractAddress,
        bytes4 interfaceId
    ) internal view returns (bool) {
        return
            uint256(
                getMappingValue(
                    contractAddress,
                    SUPPORTED_INTERFACE,
                    bytes32(interfaceId)
                )
            ) != 0;
    }

    function getStaked(
        address contractAddress,
        address tokenAddress
    ) internal view returns (uint256) {
        return
            uint256(
                getMappingValue(
                    contractAddress,
                    STAKED,
                    bytes32(uint256(uint160(tokenAddress)))
                )
            );
    }

    function setMinter(address contractAddress, address minter) internal {
        setStorageAddress(contractAddress, MINTER, minter);
    }

    function getMinter(
        address contractAddress
    ) internal view returns (address) {
        return getStorageAddress(contractAddress, MINTER);
    }

    function setIsNecessaryToCheckLock(
        address contractAddress,
        address token,
        bool isNecessaryToCheckLock
    ) internal {
        setMappingValue(
            contractAddress,
            IS_NECESSARY_TO_CHECK_LOCK,
            bytes32(uint256(uint160(token))),
            bytes32(uint256(isNecessaryToCheckLock ? 1 : 0))
        );
    }

    function getIsNecessaryToCheckLock(
        address contractAddress,
        address token
    ) internal view returns (bool) {
        return
            uint256(
                getMappingValue(
                    contractAddress,
                    IS_NECESSARY_TO_CHECK_LOCK,
                    bytes32(uint256(uint160(token)))
                )
            ) != 0;
    }
}

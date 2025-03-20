// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IGenericMoreVaultFacet} from "../interfaces/facets/IGenericMoreVaultFacet.sol";
import {ERC4626Upgradeable, SafeERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IVaultFacet} from "../interfaces/facets/IVaultFacet.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";

contract VaultFacet is
    ERC4626Upgradeable,
    PausableUpgradeable,
    IVaultFacet,
    BaseFacetInitializer
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using Math for uint256;

    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.MoreVaults");
    }

    function facetName() external pure returns (string memory) {
        return "VaultFacet";
    }

    function initialize(
        bytes calldata data
    ) external initializerFacet initializer {
        (
            string memory name,
            string memory symbol,
            address asset,
            address feeRecipient,
            uint96 fee
        ) = abi.decode(data, (string, string, address, address, uint96));
        if (asset == address(0) || feeRecipient == address(0))
            revert InvalidParameters();
        if (fee > 10000) revert InvalidParameters(); // max 100% = 10000 basis points

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        // Facet interfaces
        ds.supportedInterfaces[type(IERC4626).interfaceId] = true; // ERC4626 base interface
        ds.supportedInterfaces[type(IVaultFacet).interfaceId] = true; // VaultFacet (extended ERC4626)

        ds.feeRecipient = feeRecipient;
        ds.fee = fee;
        __ERC4626_init(IERC20(asset));
        __ERC20_init(name, symbol);
        ds.availableAssets.push(asset);
    }

    function paused()
        public
        view
        override(PausableUpgradeable, IVaultFacet)
        returns (bool)
    {
        return super.paused();
    }

    function pause() external {
        AccessControlLib.validateCurator(msg.sender);
        _pause();
    }

    function unpause() external {
        AccessControlLib.validateCurator(msg.sender);
        _unpause();
    }

    function totalAssets()
        public
        view
        override(ERC4626Upgradeable, IVaultFacet)
        returns (uint256 _totalAssets)
    {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address[] memory facets = ds.facetsForAccounting;

        for (uint i; i < ds.availableAssets.length; ) {
            _totalAssets += MoreVaultsLib.convertToUnderlying(
                ds.availableAssets[i],
                IERC20(ds.availableAssets[i]).balanceOf(address(this))
            );
            unchecked {
                ++i;
            }
        }

        for (uint i; i < facets.length; ) {
            (bool success, bytes memory result) = address(this).staticcall(
                abi.encodeWithSignature(
                    string.concat(
                        "accounting",
                        IGenericMoreVaultFacet(facets[i]).facetName(),
                        "()"
                    ),
                    ""
                )
            );
            if (success) {
                uint256 decodedAmount = abi.decode(result, (uint256));
                _totalAssets += decodedAmount;
            } else revert AccountingFailed(facets[i]);
            unchecked {
                ++i;
            }
        }
    }

    function deposit(
        uint256 assets,
        address receiver
    )
        public
        virtual
        override(ERC4626Upgradeable, IVaultFacet)
        whenNotPaused
        returns (uint256)
    {
        _accrueInterest();

        return super.deposit(assets, receiver);
    }

    function mint(
        uint256 shares,
        address receiver
    )
        public
        virtual
        override(ERC4626Upgradeable, IVaultFacet)
        whenNotPaused
        returns (uint256)
    {
        _accrueInterest();

        return super.mint(shares, receiver);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        virtual
        override(ERC4626Upgradeable, IVaultFacet)
        whenNotPaused
        returns (uint256)
    {
        _accrueInterest();

        return super.withdraw(assets, receiver, owner);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        virtual
        override(ERC4626Upgradeable, IVaultFacet)
        whenNotPaused
        returns (uint256)
    {
        _accrueInterest();

        return super.redeem(shares, receiver, owner);
    }

    function deposit(
        address[] calldata tokens,
        uint256[] calldata assets,
        address receiver
    ) external whenNotPaused returns (uint256) {
        _accrueInterest();

        if (assets.length != tokens.length)
            revert ArraysLengthsDontMatch(assets.length, tokens.length);

        uint256 totalConvertedAmount;
        for (uint i; i < tokens.length; ) {
            MoreVaultsLib.validateAsset(tokens[i]);
            totalConvertedAmount += MoreVaultsLib.convertToUnderlying(
                tokens[i],
                assets[i]
            );
            unchecked {
                ++i;
            }
        }

        uint256 maxAssets = maxDeposit(receiver);
        if (totalConvertedAmount > maxAssets) {
            revert ERC4626ExceededMaxDeposit(
                receiver,
                totalConvertedAmount,
                maxAssets
            );
        }

        uint256 shares = previewDeposit(totalConvertedAmount);
        _deposit(_msgSender(), receiver, tokens, assets, shares);

        return shares;
    }

    /**
     * @dev Deposit/mint common workflow.
     */
    function _deposit(
        address caller,
        address receiver,
        address[] calldata tokens,
        uint256[] calldata assets,
        uint256 shares
    ) internal {
        for (uint i; i < assets.length; ) {
            SafeERC20.safeTransferFrom(
                IERC20(tokens[i]),
                caller,
                address(this),
                assets[i]
            );
            unchecked {
                ++i;
            }
        }
        _mint(receiver, shares);

        emit Deposit(caller, receiver, tokens, assets, shares);
    }

    function _accrueInterest() internal {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        ds.lastTotalAssets = newTotalAssets;

        if (feeShares != 0) _mint(ds.feeRecipient, feeShares);

        emit AccrueInterest(newTotalAssets, feeShares);
    }

    function _accruedFeeShares()
        internal
        view
        returns (uint256 feeShares, uint256 newTotalAssets)
    {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        newTotalAssets = totalAssets();

        uint256 lastTotalAssets = ds.lastTotalAssets;
        uint256 totalInterest = newTotalAssets > lastTotalAssets
            ? newTotalAssets - lastTotalAssets
            : 0;

        uint96 fee = ds.fee;
        if (totalInterest != 0 && fee != 0) {
            uint256 feeAssets = totalInterest.mulDiv(fee, 1e18);
            feeShares = feeShares.mulDiv(
                totalSupply() + 10 ** _decimalsOffset(),
                newTotalAssets - feeAssets,
                Math.Rounding.Floor
            );
        }
    }
}

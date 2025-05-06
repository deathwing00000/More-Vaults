// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IGenericMoreVaultFacet} from "../interfaces/facets/IGenericMoreVaultFacet.sol";
import {ERC4626Upgradeable, SafeERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IVaultFacet} from "../interfaces/facets/IVaultFacet.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";

contract VaultFacet is
    ERC4626Upgradeable,
    PausableUpgradeable,
    IVaultFacet,
    BaseFacetInitializer
{
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
            uint96 fee,
            uint256 depositCapacity
        ) = abi.decode(
                data,
                (string, string, address, address, uint96, uint256)
            );
        if (
            asset == address(0) ||
            feeRecipient == address(0) ||
            fee > MoreVaultsLib.FEE_BASIS_POINT
        ) revert InvalidParameters();

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        // Facet interfaces
        ds.supportedInterfaces[type(IERC20).interfaceId] = true; // ERC20 interface
        ds.supportedInterfaces[type(IERC4626).interfaceId] = true; // ERC4626 base interface
        ds.supportedInterfaces[type(IVaultFacet).interfaceId] = true; // VaultFacet (extended ERC4626)

        MoreVaultsLib._setFeeRecipient(feeRecipient);
        MoreVaultsLib._setFee(fee);
        MoreVaultsLib._setDepositCapacity(depositCapacity);
        __ERC4626_init(IERC20(asset));
        __ERC20_init(name, symbol);
        MoreVaultsLib._addAvailableAsset(asset);
        MoreVaultsLib._enableAssetToDeposit(asset);
    }

    /**
     * @inheritdoc IVaultFacet
     */
    function paused()
        public
        view
        override(PausableUpgradeable, IVaultFacet)
        returns (bool)
    {
        return super.paused();
    }

    /**
     * @inheritdoc IVaultFacet
     */
    function pause() external {
        AccessControlLib.validateOwner(msg.sender);
        _pause();
    }

    /**
     * @inheritdoc IVaultFacet
     */
    function unpause() external {
        AccessControlLib.validateOwner(msg.sender);
        _unpause();
    }

    /**
     * @inheritdoc IVaultFacet
     */
    function totalAssets()
        public
        view
        override(ERC4626Upgradeable, IVaultFacet)
        returns (uint256 _totalAssets)
    {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address[] memory facets = ds.facetsForAccounting;
        address wrappedNative = ds.wrappedNative;

        for (uint i; i < ds.availableAssets.length; ) {
            address asset = ds.availableAssets[i];
            _totalAssets += MoreVaultsLib.convertToUnderlying(
                asset,
                IERC20(asset).balanceOf(address(this)) + ds.staked[asset]
            );
            if (wrappedNative == asset) {
                _totalAssets += MoreVaultsLib.convertToUnderlying(
                    wrappedNative,
                    address(this).balance
                );
            }
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

    /**
     * @notice override maxDeposit to check if the deposit capacity is exceeded
     * @dev Warning: the returned value can be slightly higher since accrued fee are not included.
     */
    function maxDeposit(
        address // receiver
    ) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        uint256 assetsInVault = totalAssets();
        if (ds.depositCapacity == 0) {
            return type(uint256).max;
        }
        if (assetsInVault > ds.depositCapacity) {
            return 0;
        } else {
            return ds.depositCapacity - assetsInVault;
        }
    }

    /**
     * @notice override maxMint to check if the deposit capacity is exceeded
     * @dev Warning: the returned value can be slightly higher since accrued fee are not included.
     */
    function maxMint(
        address // receiver
    ) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        uint256 assetsInVault = totalAssets();
        if (ds.depositCapacity == 0) {
            return type(uint256).max;
        }
        if (assetsInVault > ds.depositCapacity) {
            return 0;
        } else {
            return
                _convertToShares(
                    ds.depositCapacity - assetsInVault,
                    Math.Rounding.Floor
                );
        }
    }

    /**
     * @inheritdoc IVaultFacet
     */
    function deposit(
        uint256 assets,
        address receiver
    )
        public
        virtual
        override(ERC4626Upgradeable, IVaultFacet)
        whenNotPaused
        returns (uint256 shares)
    {
        uint256 newTotalAssets = _accrueInterest();

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        _validateCapacity(receiver, newTotalAssets, assets);

        ds.lastTotalAssets = newTotalAssets;

        shares = _convertToSharesWithTotals(
            assets,
            totalSupply(),
            newTotalAssets,
            Math.Rounding.Floor
        );
        _deposit(_msgSender(), receiver, assets, shares);
    }

    /**
     * @inheritdoc IVaultFacet
     */
    function mint(
        uint256 shares,
        address receiver
    )
        public
        virtual
        override(ERC4626Upgradeable, IVaultFacet)
        whenNotPaused
        returns (uint256 assets)
    {
        uint256 newTotalAssets = _accrueInterest();

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        ds.lastTotalAssets = newTotalAssets;

        assets = _convertToAssetsWithTotals(
            shares,
            totalSupply(),
            newTotalAssets,
            Math.Rounding.Floor
        );
        _validateCapacity(receiver, newTotalAssets, assets);
        _deposit(_msgSender(), receiver, assets, shares);
    }

    /**
     * @inheritdoc IVaultFacet
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        virtual
        override(ERC4626Upgradeable, IVaultFacet)
        whenNotPaused
        returns (uint256 shares)
    {
        uint256 newTotalAssets = _accrueInterest();

        shares = _convertToSharesWithTotals(
            assets,
            totalSupply(),
            newTotalAssets,
            Math.Rounding.Ceil
        );

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.lastTotalAssets = newTotalAssets > assets
            ? newTotalAssets - assets
            : 0;

        _withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /**
     * @inheritdoc IVaultFacet
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        virtual
        override(ERC4626Upgradeable, IVaultFacet)
        whenNotPaused
        returns (uint256 assets)
    {
        uint256 newTotalAssets = _accrueInterest();

        assets = _convertToAssetsWithTotals(
            shares,
            totalSupply(),
            newTotalAssets,
            Math.Rounding.Ceil
        );

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.lastTotalAssets = newTotalAssets > assets
            ? newTotalAssets - assets
            : 0;

        _withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /**
     * @inheritdoc IVaultFacet
     */
    function deposit(
        address[] calldata tokens,
        uint256[] calldata assets,
        address receiver
    ) external whenNotPaused returns (uint256 shares) {
        uint256 newTotalAssets = _accrueInterest();

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        ds.lastTotalAssets = newTotalAssets;

        if (assets.length != tokens.length)
            revert ArraysLengthsDontMatch(tokens.length, assets.length);

        uint256 totalConvertedAmount;
        for (uint i; i < tokens.length; ) {
            MoreVaultsLib.validateAssetDepositable(tokens[i]);
            totalConvertedAmount += MoreVaultsLib.convertToUnderlying(
                tokens[i],
                assets[i]
            );
            unchecked {
                ++i;
            }
        }

        _validateCapacity(receiver, newTotalAssets, totalConvertedAmount);

        shares = _convertToSharesWithTotals(
            totalConvertedAmount,
            totalSupply(),
            newTotalAssets,
            Math.Rounding.Floor
        );
        _deposit(_msgSender(), receiver, tokens, assets, shares);

        ds.lastTotalAssets = ds.lastTotalAssets + totalConvertedAmount;
    }

    function _convertToSharesWithTotals(
        uint256 assets,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        return
            assets.mulDiv(
                newTotalSupply + 10 ** _decimalsOffset(),
                newTotalAssets + 1,
                rounding
            );
    }

    function _convertToAssetsWithTotals(
        uint256 shares,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        return
            shares.mulDiv(
                newTotalAssets + 1,
                newTotalSupply + 10 ** _decimalsOffset(),
                rounding
            );
    }

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        super._deposit(caller, receiver, assets, shares);

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.lastTotalAssets = ds.lastTotalAssets + assets;
    }

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

    function _accrueInterest() internal returns (uint256 newTotalAssets) {
        uint256 feeShares;
        (feeShares, newTotalAssets) = _accruedFeeShares();
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        AccessControlLib.AccessControlStorage storage acs = AccessControlLib
            .accessControlStorage();

        ds.lastTotalAssets = newTotalAssets;

        (
            address protocolFeeRecipient,
            uint96 protocolFee
        ) = IMoreVaultsRegistry(acs.moreVaultsRegistry).protocolFeeInfo(
                address(this)
            );
        if (feeShares != 0) {
            if (protocolFee != 0) {
                uint256 protocolFeeShares = feeShares.mulDiv(
                    protocolFee,
                    MoreVaultsLib.FEE_BASIS_POINT
                );
                _mint(protocolFeeRecipient, protocolFeeShares);
                _mint(ds.feeRecipient, feeShares - protocolFeeShares);
            } else _mint(ds.feeRecipient, feeShares);
        }

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
            uint256 feeAssets = totalInterest.mulDiv(
                fee,
                MoreVaultsLib.FEE_BASIS_POINT
            );
            feeShares = feeAssets.mulDiv(
                totalSupply() + 10 ** _decimalsOffset(),
                newTotalAssets - feeAssets,
                Math.Rounding.Floor
            );
        }
    }

    function _validateCapacity(
        address receiver,
        uint256 newTotalAssets,
        uint256 newAssets
    ) internal view {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        uint256 depositCapacity = ds.depositCapacity;
        if (depositCapacity == 0) {
            return;
        }
        if (newTotalAssets + newAssets > depositCapacity) {
            uint256 maxToDeposit;
            if (newTotalAssets < depositCapacity) {
                maxToDeposit = depositCapacity - newTotalAssets;
            }
            revert ERC4626ExceededMaxDeposit(receiver, newAssets, maxToDeposit);
        }
    }
}

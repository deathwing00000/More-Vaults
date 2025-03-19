// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {IPoolAddressesProviderRegistry} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProviderRegistry.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {ICreditDelegationToken} from "@aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";
import {IPool, DataTypes} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {ReserveConfiguration} from "@aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {IAaveV3RewardsController} from "../interfaces/Aave/v3/IAaveV3RewardsController.sol";
import {IATokenExtended} from "../interfaces/Aave/v3/IATokenExtended.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";
import {IAaveOracle} from "@aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {IMoreMarketsFacet} from "../interfaces/facets/IMoreMarketsFacet.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";

contract MoreMarketsFacet is BaseFacetInitializer, IMoreMarketsFacet {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Math for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    bytes32 constant MTOKENS_ID = keccak256("MTOKENS_ID");
    bytes32 constant MORE_DEBT_TOKENS_ID = keccak256("MORE_DEBT_TOKENS_ID");

    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.MoreMarketsFacet");
    }

    function initialize(bytes calldata data) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address facetAddress = abi.decode(data, (address));
        ds.facetsForAccounting.push(facetAddress);
    }

    function facetName() external pure returns (string memory) {
        return "MoreMarketsFacet";
    }

    function accountingMoreMarketsFacet() public view returns (uint sum) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        EnumerableSet.AddressSet storage mTokensHeld = ds.tokensHeld[
            MTOKENS_ID
        ];
        EnumerableSet.AddressSet storage debtTokensHeld = ds.tokensHeld[
            MORE_DEBT_TOKENS_ID
        ];

        for (uint i = 0; i < mTokensHeld.length(); ) {
            address mToken = mTokensHeld.at(i);
            uint balance = IERC20(mToken).balanceOf(address(this));
            address underlyingOfMToken = IATokenExtended(mToken)
                .UNDERLYING_ASSET_ADDRESS();
            sum += MoreVaultsLib.convertToUnderlying(
                underlyingOfMToken,
                balance
            );
            unchecked {
                ++i;
            }
        }
        for (uint i = 0; i < debtTokensHeld.length(); ) {
            address debtToken = debtTokensHeld.at(i);
            uint balance = IERC20(debtToken).balanceOf(address(this));
            address underlyingOfDebtToken = IATokenExtended(debtToken)
                .UNDERLYING_ASSET_ADDRESS();

            sum -= MoreVaultsLib.convertToUnderlying(
                underlyingOfDebtToken,
                balance
            );
            unchecked {
                ++i;
            }
        }
    }

    function approveDelegation(
        address debtToken,
        address delegatee,
        uint256 amount
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        ICreditDelegationToken(debtToken).approveDelegation(delegatee, amount);
    }

    function supply(
        address pool,
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        _validatePool(pool);
        MoreVaultsLib.validateAsset(asset);
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        IERC20(asset).approve(pool, amount);
        IPool(pool).supply(asset, amount, onBehalfOf, referralCode);
        address mToken = IPool(pool).getReserveData(asset).aTokenAddress;
        ds.tokensHeld[MTOKENS_ID].add(mToken);
    }

    function withdraw(
        address pool,
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256 withdrawnAmount) {
        _validatePool(pool);
        MoreVaultsLib.validateAsset(asset);
        AccessControlLib.validateDiamond(msg.sender);

        return _withdraw(pool, asset, amount, to);
    }

    function borrow(
        address pool,
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        _validatePool(pool);
        MoreVaultsLib.validateAsset(asset);

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        IPool(pool).borrow(
            asset,
            amount,
            interestRateMode,
            referralCode,
            onBehalfOf
        );

        address debtToken;
        if (interestRateMode == 1)
            debtToken = IPool(pool)
                .getReserveData(asset)
                .stableDebtTokenAddress;
        else
            debtToken = IPool(pool)
                .getReserveData(asset)
                .variableDebtTokenAddress;
        ds.tokensHeld[MORE_DEBT_TOKENS_ID].add(debtToken);
    }

    function repay(
        address pool,
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external virtual returns (uint256 repaidAmount) {
        AccessControlLib.validateDiamond(msg.sender);
        _validatePool(pool);
        MoreVaultsLib.validateAsset(asset);

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        IERC20(asset).approve(pool, amount);
        repaidAmount = IPool(pool).repay(
            asset,
            amount,
            interestRateMode,
            onBehalfOf
        );

        address debtToken;
        if (interestRateMode == 1)
            debtToken = IPool(pool)
                .getReserveData(asset)
                .stableDebtTokenAddress;
        else
            debtToken = IPool(pool)
                .getReserveData(asset)
                .variableDebtTokenAddress;

        MoreVaultsLib.removeTokenIfnecessary(
            ds.tokensHeld[MORE_DEBT_TOKENS_ID],
            debtToken
        );
    }

    function repayWithATokens(
        address pool,
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external returns (uint256 repaidAmount) {
        AccessControlLib.validateDiamond(msg.sender);
        _validatePool(pool);
        MoreVaultsLib.validateAsset(asset);

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address mToken = IPool(pool).getReserveData(asset).aTokenAddress;

        IERC20(mToken).approve(pool, amount);
        repaidAmount = IPool(pool).repayWithATokens(
            asset,
            amount,
            interestRateMode
        );

        address debtToken;
        if (interestRateMode == 1)
            debtToken = IPool(pool)
                .getReserveData(asset)
                .stableDebtTokenAddress;
        else
            debtToken = IPool(pool)
                .getReserveData(asset)
                .variableDebtTokenAddress;

        MoreVaultsLib.removeTokenIfnecessary(
            ds.tokensHeld[MORE_DEBT_TOKENS_ID],
            debtToken
        );
    }

    function swapBorrowRateMode(
        address pool,
        address asset,
        uint256 interestRateMode
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        _validatePool(pool);
        MoreVaultsLib.validateAsset(asset);

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        IPool(pool).swapBorrowRateMode(asset, interestRateMode);

        address stableDebtToken = IPool(pool)
            .getReserveData(asset)
            .stableDebtTokenAddress;
        address variableDebtToken = IPool(pool)
            .getReserveData(asset)
            .variableDebtTokenAddress;
        if (interestRateMode == 1) {
            ds.tokensHeld[MORE_DEBT_TOKENS_ID].remove(variableDebtToken);
            ds.tokensHeld[MORE_DEBT_TOKENS_ID].add(stableDebtToken);
        } else {
            ds.tokensHeld[MORE_DEBT_TOKENS_ID].remove(stableDebtToken);
            ds.tokensHeld[MORE_DEBT_TOKENS_ID].add(variableDebtToken);
        }
    }

    function rebalanceStableBorrowRate(
        address pool,
        address asset,
        address user
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        _validatePool(pool);
        MoreVaultsLib.validateAsset(asset);

        IPool(pool).rebalanceStableBorrowRate(asset, user);
    }

    function setUserUseReserveAsCollateral(
        address pool,
        address asset,
        bool useAsCollateral
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        _validatePool(pool);
        MoreVaultsLib.validateAsset(asset);
        IPool(pool).setUserUseReserveAsCollateral(asset, useAsCollateral);
    }

    function flashLoan(
        address pool,
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        _validatePool(pool);

        IPool(pool).flashLoan(
            receiverAddress,
            assets,
            amounts,
            interestRateModes,
            onBehalfOf,
            params,
            referralCode
        );
    }

    function flashLoanSimple(
        address pool,
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) public {
        AccessControlLib.validateDiamond(msg.sender);
        _validatePool(pool);
        MoreVaultsLib.validateAsset(asset);

        IPool(pool).flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
    }

    function setUserEMode(address pool, uint8 categoryId) external {
        AccessControlLib.validateDiamond(msg.sender);
        _validatePool(pool);

        IPool(pool).setUserEMode(categoryId);
    }

    function claimAllRewards(
        address rewardsController,
        address[] calldata assets,
        address to
    )
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        for (uint i; i < assets.length; ) {
            if (!ds.isAssetAvailable[assets[i]] && to == address(this))
                revert UnsupportedAsset(assets[i]);
            unchecked {
                ++i;
            }
        }

        return
            IAaveV3RewardsController(rewardsController).claimAllRewards(
                assets,
                to
            );
    }

    function _withdraw(
        address pool,
        address asset,
        uint256 amount,
        address to
    ) internal returns (uint256 withdrawnAmount) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address mToken = IPool(pool).getReserveData(asset).aTokenAddress;

        IERC20(mToken).approve(pool, amount);
        withdrawnAmount = IPool(pool).withdraw(asset, amount, to);

        MoreVaultsLib.removeTokenIfnecessary(ds.tokensHeld[MTOKENS_ID], mToken);
    }

    function _validatePool(address pool) internal view {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address registry = ds.morePoolAddressesProviderRegistry;
        address[] memory providers = IPoolAddressesProviderRegistry(registry)
            .getAddressesProvidersList();
        for (uint i; i < providers.length; ) {
            if (pool == IPoolAddressesProvider(providers[i]).getPool()) return;
            unchecked {
                ++i;
            }
        }
        revert UnsupportedPool(pool);
    }
}

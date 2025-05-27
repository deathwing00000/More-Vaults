// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {IPoolAddressesProviderRegistry} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProviderRegistry.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import {ICreditDelegationToken} from "@aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";
import {IPool, DataTypes} from "@aave-v3-core/contracts/interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {IAaveV3RewardsController} from "../interfaces/Aave/v3/IAaveV3RewardsController.sol";
import {IATokenExtended} from "../interfaces/Aave/v3/IATokenExtended.sol";
import {IMoreVaultsRegistry} from "../interfaces/IMoreVaultsRegistry.sol";
import {IAaveV3Facet} from "../interfaces/facets/IAaveV3Facet.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract AaveV3Facet is BaseFacetInitializer, IAaveV3Facet {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 constant MTOKENS_ID = keccak256("MTOKENS_ID");
    bytes32 constant MORE_DEBT_TOKENS_ID = keccak256("MORE_DEBT_TOKENS_ID");

    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.AaveV3Facet");
    }

    function initialize(bytes calldata data) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address facetAddress = abi.decode(data, (address));
        ds.facetsForAccounting.push(facetAddress);

        ds.supportedInterfaces[type(IAaveV3Facet).interfaceId] = true;
    }

    function facetName() external pure returns (string memory) {
        return "AaveV3Facet";
    }

    function accountingAaveV3Facet() public view returns (uint sum) {
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
            if (ds.isAssetAvailable[mToken]) {
                unchecked {
                    ++i;
                }
                continue;
            }
            uint balance = IERC20(mToken).balanceOf(address(this)) +
                ds.staked[mToken];
            address underlyingOfMToken = IATokenExtended(mToken)
                .UNDERLYING_ASSET_ADDRESS();
            sum += MoreVaultsLib.convertToUnderlying(
                underlyingOfMToken,
                balance,
                Math.Rounding.Floor
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
                balance,
                Math.Rounding.Ceil
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @inheritdoc IAaveV3Facet
     */
    function supply(
        address pool,
        address asset,
        uint256 amount,
        uint16 referralCode
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAssetAvailable(asset);
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        IERC20(asset).forceApprove(pool, amount);
        IPool(pool).supply(asset, amount, address(this), referralCode);
        address mToken = IPool(pool).getReserveData(asset).aTokenAddress;
        ds.tokensHeld[MTOKENS_ID].add(mToken);
    }

    /**
     * @inheritdoc IAaveV3Facet
     */
    function withdraw(
        address pool,
        address asset,
        uint256 amount
    ) external returns (uint256 withdrawnAmount) {
        MoreVaultsLib.validateAssetAvailable(asset);
        AccessControlLib.validateDiamond(msg.sender);

        return _withdraw(pool, asset, amount, address(this));
    }

    /**
     * @inheritdoc IAaveV3Facet
     */
    function borrow(
        address pool,
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAssetAvailable(asset);

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
        if (onBehalfOf == address(this)) {
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
    }

    /**
     * @inheritdoc IAaveV3Facet
     */
    function repay(
        address pool,
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external virtual returns (uint256 repaidAmount) {
        AccessControlLib.validateDiamond(msg.sender);

        MoreVaultsLib.validateAssetAvailable(asset);

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        IERC20(asset).forceApprove(pool, amount);
        repaidAmount = IPool(pool).repay(
            asset,
            amount,
            interestRateMode,
            address(this)
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

    /**
     * @inheritdoc IAaveV3Facet
     */
    function repayWithATokens(
        address pool,
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external returns (uint256 repaidAmount) {
        AccessControlLib.validateDiamond(msg.sender);

        MoreVaultsLib.validateAssetAvailable(asset);

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address mToken = IPool(pool).getReserveData(asset).aTokenAddress;

        IERC20(mToken).forceApprove(pool, amount);
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

        MoreVaultsLib.removeTokenIfnecessary(ds.tokensHeld[MTOKENS_ID], mToken);
    }

    /**
     * @inheritdoc IAaveV3Facet
     */
    function swapBorrowRateMode(
        address pool,
        address asset,
        uint256 interestRateMode
    ) external {
        AccessControlLib.validateDiamond(msg.sender);

        MoreVaultsLib.validateAssetAvailable(asset);

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

    /**
     * @inheritdoc IAaveV3Facet
     */
    function rebalanceStableBorrowRate(
        address pool,
        address asset,
        address user
    ) external {
        AccessControlLib.validateDiamond(msg.sender);

        MoreVaultsLib.validateAssetAvailable(asset);

        IPool(pool).rebalanceStableBorrowRate(asset, user);
    }

    /**
     * @inheritdoc IAaveV3Facet
     */
    function setUserUseReserveAsCollateral(
        address pool,
        address asset,
        bool useAsCollateral
    ) external {
        AccessControlLib.validateDiamond(msg.sender);

        MoreVaultsLib.validateAssetAvailable(asset);
        IPool(pool).setUserUseReserveAsCollateral(asset, useAsCollateral);
    }

    /**
     * @inheritdoc IAaveV3Facet
     */
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

        IPool(pool).flashLoan(
            receiverAddress,
            assets,
            amounts,
            interestRateModes,
            onBehalfOf,
            params,
            referralCode
        );

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address debtToken;
        if (onBehalfOf == address(this)) {
            for (uint256 i = 0; i < interestRateModes.length; ) {
                if (interestRateModes[i] == 0) {
                    unchecked {
                        ++i;
                    }
                    continue;
                }

                MoreVaultsLib.validateAssetAvailable(assets[i]);
                if (interestRateModes[i] == 1)
                    debtToken = IPool(pool)
                        .getReserveData(assets[i])
                        .stableDebtTokenAddress;
                else
                    debtToken = IPool(pool)
                        .getReserveData(assets[i])
                        .variableDebtTokenAddress;
                ds.tokensHeld[MORE_DEBT_TOKENS_ID].add(debtToken);
                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @inheritdoc IAaveV3Facet
     */
    function flashLoanSimple(
        address pool,
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) public {
        AccessControlLib.validateDiamond(msg.sender);

        MoreVaultsLib.validateAssetAvailable(asset);

        IPool(pool).flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
    }

    /**
     * @inheritdoc IAaveV3Facet
     */
    function setUserEMode(address pool, uint8 categoryId) external {
        AccessControlLib.validateDiamond(msg.sender);

        IPool(pool).setUserEMode(categoryId);
    }

    /**
     * @inheritdoc IAaveV3Facet
     */
    function claimAllRewards(
        address rewardsController,
        address[] calldata assets
    )
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        AccessControlLib.validateDiamond(msg.sender);
        for (uint i; i < assets.length; ) {
            MoreVaultsLib.validateAssetAvailable(assets[i]);
            unchecked {
                ++i;
            }
        }

        return
            IAaveV3RewardsController(rewardsController).claimAllRewards(
                assets,
                address(this)
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

        IERC20(mToken).forceApprove(pool, amount);
        withdrawnAmount = IPool(pool).withdraw(asset, amount, to);

        MoreVaultsLib.removeTokenIfnecessary(ds.tokensHeld[MTOKENS_ID], mToken);
    }
}

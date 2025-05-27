// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ILiquidityGaugeV6} from "../interfaces/Curve/ILiquidityGaugeV6.sol";
import {IMinter} from "../interfaces/Curve/IMinter.sol";
import {ICurveLiquidityGaugeV6Facet} from "../interfaces/facets/ICurveLiquidityGaugeV6Facet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title CurveLiquidityGaugeV6Facet
 * @notice Facet for handling staking into LiquidityGaugeV6 smart contract
 * @dev Implements functionality to stake/withdraw of the lp tokens and claim of rewards
 */
contract CurveLiquidityGaugeV6Facet is
    ICurveLiquidityGaugeV6Facet,
    BaseFacetInitializer
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 constant CURVE_LIQUIDITY_GAUGES_V6_ID =
        keccak256("CURVE_LIQUIDITY_GAUGES_V6_ID");

    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return
            keccak256(
                "MoreVaults.storage.initializable.CurveLiquidityGaugeV6Facet"
            );
    }

    /**
     * @notice Returns the name of the facet
     * @return The facet name
     */
    function facetName() external pure returns (string memory) {
        return "CurveLiquidityGaugeV6Facet";
    }

    function accountingCurveLiquidityGaugeV6Facet()
        external
        view
        returns (uint256 sum)
    {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        EnumerableSet.AddressSet storage gauges = ds.stakingAddresses[
            CURVE_LIQUIDITY_GAUGES_V6_ID
        ];

        for (uint256 i = 0; i < gauges.length(); ) {
            ILiquidityGaugeV6 gauge = ILiquidityGaugeV6(gauges.at(i));
            uint256 numberOfRewardTokens = gauge.reward_count();

            for (uint256 j = 0; j < numberOfRewardTokens; ) {
                address rewardToken = gauge.reward_tokens(j);
                uint256 reward = gauge.claimable_reward(
                    address(this),
                    rewardToken
                );

                sum += MoreVaultsLib.convertToUnderlying(
                    rewardToken,
                    reward,
                    Math.Rounding.Floor
                );
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    function initialize(bytes calldata data) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.supportedInterfaces[
            type(ICurveLiquidityGaugeV6Facet).interfaceId
        ] = true;
        address facetAddress = abi.decode(data, (address));
        ds.facetsForAccounting.push(facetAddress);
    }

    /**
     * @inheritdoc ICurveLiquidityGaugeV6Facet
     */
    function depositCurveGaugeV6(address gauge, uint256 amount) external {
        AccessControlLib.validateDiamond(msg.sender);
        ILiquidityGaugeV6 _gauge = ILiquidityGaugeV6(gauge);
        uint256 numberOfRewardTokens = _gauge.reward_count();

        for (uint256 i = 0; i < numberOfRewardTokens; ) {
            address rewardToken = _gauge.reward_tokens(i);
            MoreVaultsLib.validateAssetAvailable(rewardToken);
            unchecked {
                ++i;
            }
        }
        IERC20 lpToken = IERC20(_gauge.lp_token());
        lpToken.forceApprove(gauge, amount);
        _gauge.deposit(amount, address(this), false);

        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.stakingAddresses[CURVE_LIQUIDITY_GAUGES_V6_ID].add(gauge);
        ds.staked[address(lpToken)] += amount;
    }

    /**
     * @inheritdoc ICurveLiquidityGaugeV6Facet
     */
    function withdrawCurveGaugeV6(address gauge, uint256 amount) external {
        AccessControlLib.validateDiamond(msg.sender);
        ILiquidityGaugeV6(gauge).withdraw(amount, false);

        IERC20 lpToken = IERC20(ILiquidityGaugeV6(gauge).lp_token());
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        ds.staked[address(lpToken)] -= amount;
    }

    /**
     * @inheritdoc ICurveLiquidityGaugeV6Facet
     */
    function claimRewardsCurveGaugeV6(address gauge) external {
        AccessControlLib.validateDiamond(msg.sender);
        ILiquidityGaugeV6 _gauge = ILiquidityGaugeV6(gauge);
        uint256 numberOfRewardTokens = _gauge.reward_count();

        for (uint256 i = 0; i < numberOfRewardTokens; ) {
            address rewardToken = _gauge.reward_tokens(i);
            MoreVaultsLib.validateAssetAvailable(rewardToken);
            unchecked {
                ++i;
            }
        }
        _gauge.claim_rewards(address(this), address(this));

        if (IERC20(gauge).balanceOf(address(this)) == 0) {
            MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
                .moreVaultsStorage();
            ds.stakingAddresses[CURVE_LIQUIDITY_GAUGES_V6_ID].remove(gauge);
        }
    }

    /**
     * @inheritdoc ICurveLiquidityGaugeV6Facet
     */
    function mintCRV(address minterContract, address gauge) external {
        AccessControlLib.validateDiamond(msg.sender);
        IMinter minter = IMinter(minterContract);
        MoreVaultsLib.validateAssetAvailable(minter.token());
        minter.mint(gauge);
    }
}

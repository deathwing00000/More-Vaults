// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ICurveViews
interface ICurveViews {
    function calc_withdraw_one_coin(
        uint256 burnAmount,
        int128 i
    ) external view returns (uint256);

    function get_virtual_price() external view returns (uint256);

    function coins(uint256 i) external view returns (address);

    function remove_liquidity_one_coin(
        uint256 _tokenAmount,
        int128 i,
        uint256 _minAmount
    ) external;
}

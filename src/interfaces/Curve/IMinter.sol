// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IMinter
interface IMinter {
    function mint(address gauge) external;
    function mint_many(address[8] calldata gauges) external;
    function token() external view returns (address);
}

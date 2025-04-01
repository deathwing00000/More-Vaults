// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DeployConfig {
    // Roles
    address public curator;
    address public guardian;
    address public feeRecipient;
    address public treasury;

    // Tokens
    address public wrappedNative;
    address public usdce;
    address public aaveOracle;

    constructor(
        address _curator,
        address _guardian,
        address _feeRecipient,
        address _treasury,
        address _wrappedNative,
        address _usdce,
        address _aaveOracle
    ) {
        curator = _curator;
        guardian = _guardian;
        feeRecipient = _feeRecipient;
        treasury = _treasury;
        wrappedNative = _wrappedNative;
        usdce = _usdce;
        aaveOracle = _aaveOracle;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAggroKittyRouter {
    struct Query {
        address adapter;
        address tokenIn;
        address tokenOut;
        uint256 amountOut;
    }
    struct Offer {
        bytes amounts;
        bytes adapters;
        bytes path;
        uint256 gasEstimate;
    }
    struct FormattedOffer {
        uint256[] amounts;
        address[] adapters;
        address[] path;
        uint256 gasEstimate;
    }
    struct Trade {
        uint256 amountIn;
        uint256 amountOut;
        address[] path;
        address[] adapters;
    }

    event TrustedTokensSet(address[] indexed _newTrustedTokens);
    event AdaptersSet(address[] indexed _newAdapters);
    event FeeBpsSet(uint256 indexed _oldFeeBps, uint256 indexed _newFeeBps);
    event FeeClaimerSet(
        address indexed _oldFeeClaimer,
        address indexed _newFeeClaimer
    );
    event Swapped(
        address indexed _tokenIn,
        address indexed _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut
    );
    event ExcludedFeeSet(
        address indexed _fromToken,
        address indexed _toToken,
        bool _excluded
    );

    // admin
    function setTrustedTokens(address[] memory _trustedTokens) external;
    function setAdapters(address[] memory _adapters) external;
    function setFeeClaimer(address _claimer) external;
    function setFeeBps(uint256 _feeBps) external;
    function setExcludedFee(
        address _fromToken,
        address _toToken,
        bool _excluded,
        bool _viceVersa
    ) external;
    function setExcludedFee(
        address[] calldata _fromTokens,
        address[] calldata _toTokens,
        bool _excluded,
        bool _viceVersa
    ) external;
    function setCustomFees(
        address[] memory _partners,
        uint256[] memory _customFee
    ) external;
    function setCustomFee(address _partner, uint256 _customFee) external;
    function setCustomFees(
        address[] memory _partners,
        uint256 _customFee
    ) external;

    // misc
    function trustedTokensCount() external view returns (uint256);
    function adaptersCount() external view returns (uint256);
    function isExcludedFee(
        address _fromToken,
        address _toToken
    ) external view returns (bool);

    // query

    function queryAdapter(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint8 _index
    ) external returns (uint256);

    function queryNoSplit(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint8[] calldata _options
    ) external view returns (Query memory);

    function queryNoSplit(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) external view returns (Query memory);

    function findBestPathWithGas(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _maxSteps,
        uint256 _gasPrice
    ) external view returns (FormattedOffer memory);

    function findBestPath(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        uint256 _maxSteps
    ) external view returns (FormattedOffer memory);

    // swap

    function swapNoSplit(Trade calldata _trade, address _to) external;

    function swapNoSplitFromNative(
        Trade calldata _trade,
        address _to
    ) external payable;

    function swapNoSplitToNative(Trade calldata _trade, address _to) external;

    function swapNoSplitWithPermit(
        Trade calldata _trade,
        address _to,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    function swapNoSplitToNativeWithPermit(
        Trade calldata _trade,
        address _to,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;
}

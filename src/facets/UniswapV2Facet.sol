// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MoreVaultsLib} from "../libraries/MoreVaultsLib.sol";
import {IUniswapV2Router02} from "@uniswap-v2/v2-periphery/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../interfaces/Uniswap/v2/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../interfaces/Uniswap/v2/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {BaseFacetInitializer} from "./BaseFacetInitializer.sol";
import {IUniswapV2Facet} from "../interfaces/facets/IUniswapV2Facet.sol";

contract UniswapV2Facet is BaseFacetInitializer, IUniswapV2Facet {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Math for uint256;

    bytes32 constant UNISWAP_V2_LP_TOKENS_ID =
        keccak256("UNISWAP_V2_LP_TOKENS_ID");

    function INITIALIZABLE_STORAGE_SLOT()
        internal
        pure
        override
        returns (bytes32)
    {
        return keccak256("MoreVaults.storage.initializable.UniswapV2Facet");
    }

    function initialize(bytes calldata data) external initializerFacet {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address facetAddress = abi.decode(data, (address));
        ds.facetsForAccounting.push(facetAddress);
    }

    function facetName() public pure returns (string memory) {
        return "UniswapV2Facet";
    }

    function accountingUniswapV2Facet() public view returns (uint sum) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        EnumerableSet.AddressSet storage tokensHeld = ds.tokensHeld[
            UNISWAP_V2_LP_TOKENS_ID
        ];
        for (uint i = 0; i < tokensHeld.length(); ) {
            address lpToken = tokensHeld.at(i);
            uint totalSupply = IERC20(lpToken).totalSupply();
            uint balance = IERC20(lpToken).balanceOf(address(this));
            (uint token0, uint token1, ) = IUniswapV2Pair(lpToken)
                .getReserves();

            token0 = token0.mulDiv(balance, totalSupply);
            token1 = token1.mulDiv(balance, totalSupply);

            sum += MoreVaultsLib.convertToUnderlying(
                IUniswapV2Pair(lpToken).token0(),
                token0
            );
            sum += MoreVaultsLib.convertToUnderlying(
                IUniswapV2Pair(lpToken).token1(),
                token1
            );
            unchecked {
                ++i;
            }
        }
    }

    function addLiquidity(
        address router,
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(tokenA);
        MoreVaultsLib.validateAsset(tokenB);
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();

        IERC20(tokenA).approve(router, amountADesired);
        IERC20(tokenB).approve(router, amountBDesired);

        address defaultUniswapFactory = IUniswapV2Router02(router).factory();
        address liquidityToken = IUniswapV2Factory(defaultUniswapFactory)
            .getPair(tokenA, tokenB);
        ds.tokensHeld[UNISWAP_V2_LP_TOKENS_ID].add(liquidityToken);

        return
            IUniswapV2Router02(router).addLiquidity(
                tokenA,
                tokenB,
                amountADesired,
                amountBDesired,
                amountAMin,
                amountBMin,
                address(this),
                deadline
            );
    }

    function addLiquidityETH(
        address router,
        address token,
        uint amountTokenDesired,
        uint amountETHDesired,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    ) external returns (uint amountToken, uint amountETH, uint liquidity) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(token);
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        IERC20(token).approve(router, amountTokenDesired);

        address defaultUniswapFactory = IUniswapV2Router02(router).factory();
        address liquidityToken = IUniswapV2Factory(defaultUniswapFactory)
            .getPair(token, address(0));
        ds.tokensHeld[UNISWAP_V2_LP_TOKENS_ID].add(liquidityToken);

        return
            IUniswapV2Router02(router).addLiquidityETH{value: amountETHDesired}(
                token,
                amountTokenDesired,
                amountTokenMin,
                amountETHMin,
                address(this),
                deadline
            );
    }

    function removeLiquidity(
        address router,
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        uint deadline
    ) external returns (uint amountA, uint amountB) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(tokenA);
        MoreVaultsLib.validateAsset(tokenB);
        (amountA, amountB) = _removeLiquidity(
            router,
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            deadline
        );
    }

    function removeLiquidityETH(
        address router,
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    ) external returns (uint amountToken, uint amountETH) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(token);
        (amountToken, amountETH) = _removeLiquidityETH(
            router,
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            deadline
        );
    }

    function swapExactTokensForTokens(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(path[0]);
        MoreVaultsLib.validateAsset(path[path.length - 1]);

        IERC20(path[0]).approve(router, amountIn);
        return
            IUniswapV2Router02(router).swapExactTokensForTokens(
                amountIn,
                amountOutMin,
                path,
                address(this),
                deadline
            );
    }

    function swapTokensForExactTokens(
        address router,
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(path[0]);
        MoreVaultsLib.validateAsset(path[path.length - 1]);

        IERC20(path[0]).approve(router, amountInMax);
        return
            IUniswapV2Router02(router).swapTokensForExactTokens(
                amountOut,
                amountInMax,
                path,
                address(this),
                deadline
            );
    }

    function swapExactETHForTokens(
        address router,
        uint256 amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(path[path.length - 1]);
        return
            IUniswapV2Router02(router).swapExactETHForTokens{value: amountIn}(
                amountOutMin,
                path,
                address(this),
                deadline
            );
    }

    function swapTokensForExactETH(
        address router,
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(path[0]);

        IERC20(path[0]).approve(router, amountInMax);
        return
            IUniswapV2Router02(router).swapTokensForExactETH(
                amountOut,
                amountInMax,
                path,
                address(this),
                deadline
            );
    }

    function swapExactTokensForETH(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(path[0]);
        IERC20(path[0]).approve(router, amountIn);
        return
            IUniswapV2Router02(router).swapExactTokensForETH(
                amountIn,
                amountOutMin,
                path,
                address(this),
                deadline
            );
    }

    function swapETHForExactTokens(
        address router,
        uint256 amountInMax,
        uint amountOut,
        address[] calldata path,
        uint deadline
    ) external returns (uint[] memory amounts) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(path[path.length - 1]);
        return
            IUniswapV2Router02(router).swapETHForExactTokens{
                value: amountInMax
            }(amountOut, path, address(this), deadline);
    }

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address router,
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    ) external returns (uint amountETH) {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(token);
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address defaultUniswapFactory = IUniswapV2Router02(router).factory();
        address liquidityToken = IUniswapV2Factory(defaultUniswapFactory)
            .getPair(token, address(0));

        IERC20(liquidityToken).approve(router, liquidity);
        amountETH = IUniswapV2Router02(router)
            .removeLiquidityETHSupportingFeeOnTransferTokens(
                token,
                liquidity,
                amountTokenMin,
                amountETHMin,
                address(this),
                deadline
            );

        MoreVaultsLib.removeTokenIfnecessary(
            ds.tokensHeld[UNISWAP_V2_LP_TOKENS_ID],
            liquidityToken
        );
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(path[0]);
        MoreVaultsLib.validateAsset(path[path.length - 1]);

        IERC20(path[0]).approve(router, amountIn);
        IUniswapV2Router02(router)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountIn,
                amountOutMin,
                path,
                address(this),
                deadline
            );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        address router,
        uint256 amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(path[path.length - 1]);

        IUniswapV2Router02(router)
            .swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amountIn
        }(amountOutMin, path, address(this), deadline);
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external {
        AccessControlLib.validateDiamond(msg.sender);
        MoreVaultsLib.validateAsset(path[0]);

        IERC20(path[0]).approve(router, amountIn);
        IUniswapV2Router02(router)
            .swapExactTokensForETHSupportingFeeOnTransferTokens(
                amountIn,
                amountOutMin,
                path,
                address(this),
                deadline
            );
    }

    function _removeLiquidityETH(
        address router,
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    ) internal returns (uint amountToken, uint amountETH) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address defaultUniswapFactory = IUniswapV2Router02(router).factory();
        address liquidityToken = IUniswapV2Factory(defaultUniswapFactory)
            .getPair(token, address(0));

        IERC20(liquidityToken).approve(router, liquidity);
        (amountToken, amountETH) = IUniswapV2Router02(router)
            .removeLiquidityETH(
                token,
                liquidity,
                amountTokenMin,
                amountETHMin,
                address(this),
                deadline
            );

        MoreVaultsLib.removeTokenIfnecessary(
            ds.tokensHeld[UNISWAP_V2_LP_TOKENS_ID],
            liquidityToken
        );
    }

    function _removeLiquidity(
        address router,
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        uint deadline
    ) internal returns (uint amountA, uint amountB) {
        MoreVaultsLib.MoreVaultsStorage storage ds = MoreVaultsLib
            .moreVaultsStorage();
        address defaultUniswapFactory = IUniswapV2Router02(router).factory();
        address liquidityToken = IUniswapV2Factory(defaultUniswapFactory)
            .getPair(tokenA, tokenB);

        IERC20(liquidityToken).approve(router, liquidity);
        (amountA, amountB) = IUniswapV2Router02(router).removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            address(this),
            deadline
        );

        MoreVaultsLib.removeTokenIfnecessary(
            ds.tokensHeld[UNISWAP_V2_LP_TOKENS_ID],
            liquidityToken
        );
    }
}

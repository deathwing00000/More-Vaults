// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {VaultsRegistry} from "../../src/registry/VaultsRegistry.sol";
import {VaultsFactory} from "../../src/factory/VaultsFactory.sol";
import {MoreVaultsDiamond} from "../../src/MoreVaultsDiamond.sol";
import {IDiamondCut, DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";
import {IERC165, IDiamondLoupe, DiamondLoupeFacet} from "../../src/facets/DiamondLoupeFacet.sol";
import {IAccessControlFacet, AccessControlFacet} from "../../src/facets/AccessControlFacet.sol";
import {IConfigurationFacet, ConfigurationFacet} from "../../src/facets/ConfigurationFacet.sol";
import {IMulticallFacet, MulticallFacet} from "../../src/facets/MulticallFacet.sol";
import {IVaultFacet, VaultFacet} from "../../src/facets/VaultFacet.sol";
import {IUniswapV2Facet, UniswapV2Facet} from "../../src/facets/UniswapV2Facet.sol";
import {IMORELeverageFacet, MORELeverageFacet} from "../../src/facets/MORELeverageFacet.sol";
import {IPool, IAaveV3Facet, AaveV3Facet} from "../../src/facets/AaveV3Facet.sol";
import {IIzumiSwapFacet, IzumiSwapFacet} from "../../src/facets/IzumiSwapFacet.sol";
import {MoreVaultsStorageHelper} from "../helper/MoreVaultsStorageHelper.sol";
import {AccessControlLib} from "../../src/libraries/AccessControlLib.sol";
import {MoreVaultsLib, BALANCE_OF_SELECTOR} from "../../src/libraries/MoreVaultsLib.sol";
import {IMoreVaultsRegistry} from "../../src/interfaces/IMoreVaultsRegistry.sol";
import {IVaultsFactory} from "../../src/interfaces/IVaultsFactory.sol";
import {IVaultFacet} from "../../src/interfaces/facets/IVaultFacet.sol";
import {IUniswapV2Router02, IUniswapV2Router01} from "../../lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IOrigamiInvestment} from "../../src/interfaces/Origami/IOrigamiInvestment.sol";
import {ISwap} from "../../src/interfaces/iZUMi/ISwap.sol";
import {IAggroKittySwapFacet, AggroKittySwapFacet} from "../../src/facets/AggroKittySwapFacet.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {ICurveFacet, CurveFacet} from "../../src/facets/CurveFacet.sol";
import {IUniswapV3Facet, UniswapV3Facet} from "../../src/facets/UniswapV3Facet.sol";
import {IMultiRewardsFacet, MultiRewardsFacet} from "../../src/facets/MultiRewardsFacet.sol";
import {ICurveLiquidityGaugeV6Facet, CurveLiquidityGaugeV6Facet} from "../../src/facets/CurveLiquidityGaugeV6Facet.sol";
import {IAaveOracle} from "@aave-v3-core/contracts/interfaces/IAaveOracle.sol";
import {OracleRegistry} from "../../src/registry/OracleRegistry.sol";
import {IOracleRegistry, IAggregatorV2V3Interface} from "../../src/interfaces/IOracleRegistry.sol";
import {MockMultiRewards} from "../mocks/MockMultiRewards.sol";
import {console} from "forge-std/console.sol";

interface IAggregator {
    function latestAnswer() external view returns (int256);
    function latestTimestamp() external view returns (uint256);
    function latestRound() external view returns (uint256);
    function getAnswer(uint256 roundId) external view returns (int256);
    function getTimestamp(uint256 roundId) external view returns (uint256);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    event AnswerUpdated(
        int256 indexed current,
        uint256 indexed roundId,
        uint256 updatedAt
    );
    event NewRound(
        uint256 indexed roundId,
        address indexed startedBy,
        uint256 startedAt
    );
}

contract MockOracleWstETH {
    IAggregator immutable wstEthPriceCapAdapter;
    constructor(address _wstEthPriceCapAdapter) {
        wstEthPriceCapAdapter = IAggregator(_wstEthPriceCapAdapter);
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            0,
            wstEthPriceCapAdapter.latestAnswer(),
            block.timestamp,
            block.timestamp,
            0
        );
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }
}

contract AccountingTest is Test {
    string constant VAULT_NAME = "Test Vault";
    string constant VAULT_SYMBOL = "TV";

    // Test addresses
    address constant OWNER = address(0x1);
    address constant CURATOR = address(0x2);
    address constant USER = address(0x3);
    address constant GUARDIAN = address(0x4);
    address constant FEE_RECIPIENT = address(0x5);
    address constant TREASURY = address(0x6);
    address constant REWARDS_DISTRIBUTOR = address(0x7);

    address constant ORIGAMI_LOV_TOKEN =
        address(0x117b36e79aDadD8ea81fbc53Bfc9CD33270d845D);

    // update if needed
    address constant UNISWAP_V2_ROUTER =
        address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    address constant CURVE_ROUTER =
        address(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
    address constant USDCxWETH_UNIV2_LP =
        address(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
    address constant USDCxCrvUSD_CURVE_POOL =
        address(0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E);
    address constant CURVE_GAUGE =
        address(0x95f00391cB5EebCd190EB58728B4CE23DbFa6ac1);

    address constant AAVE_POOL =
        address(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);

    // Test tokens
    address constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address constant cbBTC =
        address(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
    address constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant wstETH =
        address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    address constant CRV = address(0xD533a949740bb3306d119CC777fa900bA034cd52);

    address constant AaveOracle =
        address(0x54586bE62E3c3580375aE3723C145253060Ca0C2);
    address constant crvMinter =
        address(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0);

    // Test constants
    uint256 constant INITIAL_BALANCE = 1000000e18;
    uint256 constant DEPOSIT_AMOUNT = 1000e18;
    uint256 constant MIN_AMOUNT_OUT = 900e18;
    uint256 public deadline;

    // Contracts
    VaultsRegistry registry;
    VaultsFactory factory;
    MoreVaultsDiamond diamond;
    DiamondCutFacet diamondCut;
    DiamondLoupeFacet diamondLoupe;
    AccessControlFacet accessControl;
    ConfigurationFacet configuration;
    MulticallFacet multicall;
    VaultFacet vault;
    UniswapV2Facet uniswapV2;
    MORELeverageFacet origami;
    AaveV3Facet moreMarkets;
    IzumiSwapFacet izumiSwap;
    AggroKittySwapFacet aggroKittySwap;
    CurveFacet curve;
    UniswapV3Facet uniswapV3;
    MultiRewardsFacet multiRewards;
    CurveLiquidityGaugeV6Facet curveGaugeV6;

    OracleRegistry oracleRegistry;

    MockOracleWstETH mockOracleWstETH;
    MockMultiRewards mockMultiRewards;

    // Mock tokens
    IERC20 usdc;
    IERC20 cbbtc;
    IERC20 weth;
    IERC20 wsteth;
    IERC20 crv;

    address vaultAddress;

    uint8 decimalsOffset = 2;
    uint256 blockNumber = 22670174;

    address[11] route;
    uint256[5][5] swapParams;

    // forge test --match-path test/integration/AccountingTest.t.sol -vvv --fork-url https://eth-mainnet.g.alchemy.com/v2/jXLoZTSjTIhZDB9nNhJsSmvrcMAbdrNT --fork-block-number 22670174
    function setUp() public {}

    function testAccountingMainnet() public {
        // Fork ETH Mainnet
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), blockNumber);
        deadline = block.timestamp + 1 hours;

        // Deploy mock tokens
        usdc = IERC20(USDC);
        cbbtc = IERC20(cbBTC);
        weth = IERC20(WETH);
        wsteth = IERC20(wstETH);
        crv = IERC20(CRV);

        // Deploy facets
        diamondCut = new DiamondCutFacet();
        diamondLoupe = new DiamondLoupeFacet();
        accessControl = new AccessControlFacet();
        configuration = new ConfigurationFacet();
        multicall = new MulticallFacet();
        vault = new VaultFacet();
        uniswapV2 = new UniswapV2Facet();
        origami = new MORELeverageFacet();
        moreMarkets = new AaveV3Facet();
        izumiSwap = new IzumiSwapFacet();
        aggroKittySwap = new AggroKittySwapFacet();
        curve = new CurveFacet();
        uniswapV3 = new UniswapV3Facet();
        multiRewards = new MultiRewardsFacet();
        curveGaugeV6 = new CurveLiquidityGaugeV6Facet();

        mockOracleWstETH = new MockOracleWstETH(
            IAaveOracle(AaveOracle).getSourceOfAsset(address(wsteth))
        );

        // setup Multirewards
        mockMultiRewards = new MockMultiRewards(OWNER, USDCxWETH_UNIV2_LP);
        vm.startPrank(OWNER);
        mockMultiRewards.addReward(
            address(usdc),
            address(REWARDS_DISTRIBUTOR),
            7 days
        );
        vm.stopPrank();
        vm.startPrank(REWARDS_DISTRIBUTOR);
        deal(USDC, REWARDS_DISTRIBUTOR, INITIAL_BALANCE);
        IERC20(USDC).approve(address(mockMultiRewards), INITIAL_BALANCE);
        mockMultiRewards.notifyRewardAmount(address(usdc), 1000 * 10 ** 6);
        vm.stopPrank();

        address[] memory assets = new address[](5);
        assets[0] = address(usdc);
        assets[1] = address(cbbtc);
        assets[2] = address(wsteth);
        assets[3] = address(weth);
        assets[4] = CRV;
        address[] memory sources = new address[](5);
        sources[0] = address(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
        sources[1] = IAaveOracle(AaveOracle).getSourceOfAsset(address(cbbtc));
        sources[2] = address(mockOracleWstETH);
        sources[3] = IAaveOracle(AaveOracle).getSourceOfAsset(address(weth));
        sources[4] = address(0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f);
        uint96[] memory confidence = new uint96[](5);
        confidence[0] = 1000000;
        confidence[1] = 1000000;
        confidence[2] = 1000000;
        confidence[3] = 1000000;
        confidence[4] = 1000000;

        IOracleRegistry.OracleInfo[]
            memory infos = new IOracleRegistry.OracleInfo[](5);
        for (uint i; i < assets.length; ) {
            infos[i] = IOracleRegistry.OracleInfo({
                aggregator: IAggregatorV2V3Interface(sources[i]),
                stalenessThreshold: confidence[i]
            });
            unchecked {
                ++i;
            }
        }

        // Deploy oracle registry
        oracleRegistry = new OracleRegistry();
        oracleRegistry.initialize(assets, infos, address(0), 8);

        // Deploy registry
        registry = new VaultsRegistry();
        registry.initialize(address(oracleRegistry), USDC);
        registry.addToWhitelist(AAVE_POOL);
        registry.addToWhitelist(UNISWAP_V2_ROUTER);
        registry.addToWhitelist(ORIGAMI_LOV_TOKEN);
        registry.addToWhitelist(address(mockMultiRewards));
        registry.addToWhitelist(CURVE_ROUTER);
        registry.addToWhitelist(CURVE_GAUGE);

        bytes4[] memory functionSelectorsDiamondCutFacet = new bytes4[](1);
        functionSelectorsDiamondCutFacet[0] = IDiamondCut.diamondCut.selector;
        bytes4[] memory functionSelectorsAccessControlFacet = new bytes4[](1);
        functionSelectorsAccessControlFacet[0] = AccessControlFacet
            .setMoreVaultsRegistry
            .selector;
        registry.addFacet(
            address(diamondCut),
            functionSelectorsDiamondCutFacet
        );
        registry.addFacet(
            address(accessControl),
            functionSelectorsAccessControlFacet
        );

        IDiamondCut.FacetCut[] memory cuts = _getCuts();

        for (uint i = 0; i < cuts.length; ) {
            registry.addFacet(cuts[i].facetAddress, cuts[i].functionSelectors);
            unchecked {
                ++i;
            }
        }
        // Deploy factory
        factory = new VaultsFactory();
        factory.initialize(
            address(registry),
            address(diamondCut),
            address(accessControl),
            WETH
        );

        bytes memory accessControlFacetInitData = abi.encode(
            OWNER,
            CURATOR,
            GUARDIAN
        );

        // Deploy diamond
        vaultAddress = factory.deployVault(cuts, accessControlFacetInitData);

        // Setup mock tokens
        deal(USDC, USER, INITIAL_BALANCE);
        deal(cbBTC, USER, INITIAL_BALANCE);
        deal(WETH, USER, INITIAL_BALANCE);
        deal(wstETH, USER, INITIAL_BALANCE);

        // Create vault
        vm.startPrank(CURATOR);
        address[] memory availableAssets = new address[](4);
        availableAssets[0] = address(cbbtc);
        availableAssets[1] = address(wsteth);
        availableAssets[2] = address(usdc);
        availableAssets[3] = CRV;
        IConfigurationFacet(vaultAddress).addAvailableAssets(availableAssets);
        IConfigurationFacet(vaultAddress).enableAssetToDeposit(address(usdc));
        IConfigurationFacet(vaultAddress).enableAssetToDeposit(address(wsteth));
        IConfigurationFacet(vaultAddress).enableAssetToDeposit(address(cbbtc));
        vm.stopPrank();

        // Approve tokens
        vm.startPrank(USER);
        usdc.approve(vaultAddress, type(uint256).max);
        cbbtc.approve(vaultAddress, type(uint256).max);
        weth.approve(vaultAddress, type(uint256).max);
        wsteth.approve(vaultAddress, type(uint256).max);
        vm.stopPrank();

        vm.startPrank(USER);
        vm.deal(USER, DEPOSIT_AMOUNT);
        IERC4626(vaultAddress).deposit(DEPOSIT_AMOUNT, USER);
        vm.stopPrank();

        assertEq(
            IERC4626(vaultAddress).balanceOf(USER),
            DEPOSIT_AMOUNT * 10 ** decimalsOffset
        );
        assertEq(IERC4626(vaultAddress).totalAssets(), DEPOSIT_AMOUNT);
        assertEq(
            IERC4626(vaultAddress).convertToAssets(
                DEPOSIT_AMOUNT * 10 ** decimalsOffset
            ),
            DEPOSIT_AMOUNT
        );
        assertEq(
            IERC4626(vaultAddress).convertToShares(DEPOSIT_AMOUNT),
            DEPOSIT_AMOUNT * 10 ** decimalsOffset
        );

        address[] memory availableAssets2 = IConfigurationFacet(vaultAddress)
            .getAvailableAssets();
        for (uint i; i < availableAssets2.length; ) {
            unchecked {
                ++i;
            }
        }
        vm.startPrank(CURATOR);
        bytes[] memory actions = new bytes[](1);
        bytes memory callData = abi.encodeWithSelector(
            IAaveV3Facet.supply.selector,
            AAVE_POOL,
            address(WETH),
            DEPOSIT_AMOUNT,
            0
        );
        actions[0] = abi.encode(address(vaultAddress), callData);
        IMulticallFacet(vaultAddress).submitActions(actions);
        assertEq(weth.balanceOf(address(vaultAddress)), 0);
        address mToken = IPool(AAVE_POOL)
            .getReserveData(address(WETH))
            .aTokenAddress;
        assertGt(IERC20(mToken).balanceOf(address(vaultAddress)), 0);
        console.log(IERC4626(vaultAddress).totalAssets());

        vm.stopPrank();

        {
            address[] memory tokensToDeposit = new address[](2);
            uint256[] memory assetsToDeposit = new uint256[](2);
            tokensToDeposit[0] = address(usdc);
            tokensToDeposit[1] = address(weth);
            assetsToDeposit[0] = 10000 * 10 ** 6;
            assetsToDeposit[1] = 1e18;

            vm.startPrank(USER);
            IVaultFacet(vaultAddress).deposit(
                tokensToDeposit,
                assetsToDeposit,
                USER
            );
            vm.stopPrank();
        }

        console.log(IERC4626(vaultAddress).totalAssets());
        vm.stopPrank();

        vm.startPrank(CURATOR);
        callData = abi.encodeWithSelector(
            IUniswapV2Facet.addLiquidity.selector,
            UNISWAP_V2_ROUTER,
            address(WETH),
            address(USDC),
            1 ether,
            2800 * 10 ** 6,
            0.9 ether,
            2600 * 10 ** 6,
            deadline
        );
        actions[0] = abi.encode(address(vaultAddress), callData);

        IMulticallFacet(vaultAddress).submitActions(actions);
        console.log(IERC4626(vaultAddress).totalAssets());

        vm.stopPrank();

        {
            address[] memory tokens = new address[](1);
            uint256[] memory assets = new uint256[](1);
            tokens[0] = address(wsteth);
            assets[0] = 1e18;

            vm.startPrank(USER);
            IVaultFacet(vaultAddress).deposit(tokens, assets, USER);
            vm.stopPrank();
        }

        console.log(IERC4626(vaultAddress).totalAssets());

        vm.startPrank(CURATOR);
        (
            IOrigamiInvestment.InvestQuoteData memory investQuoteData,

        ) = IOrigamiInvestment(ORIGAMI_LOV_TOKEN).investQuote(
                1e18,
                address(wstETH),
                100,
                block.timestamp + 100
            );
        callData = abi.encodeWithSelector(
            IMORELeverageFacet.investWithToken.selector,
            ORIGAMI_LOV_TOKEN,
            investQuoteData
        );
        actions[0] = abi.encode(address(vaultAddress), callData);

        IMulticallFacet(vaultAddress).submitActions(actions);
        console.log(IERC4626(vaultAddress).totalAssets());

        vm.stopPrank();

        vm.startPrank(CURATOR);
        callData = abi.encodeWithSelector(
            IMultiRewardsFacet.stake.selector,
            address(mockMultiRewards),
            IERC20(address(USDCxWETH_UNIV2_LP)).balanceOf(
                address(vaultAddress)
            ) / 2
        );
        actions[0] = abi.encode(address(vaultAddress), callData);

        IMulticallFacet(vaultAddress).submitActions(actions);
        console.log(IERC4626(vaultAddress).totalAssets());

        vm.stopPrank();

        vm.warp(block.timestamp + 10);
        console.log(IERC4626(vaultAddress).totalAssets());

        vm.startPrank(CURATOR);
        route[0] = USDC;
        route[1] = USDCxCrvUSD_CURVE_POOL; // USDC USDT StableSwapNg pool
        route[2] = USDCxCrvUSD_CURVE_POOL;

        swapParams[0][0] = 0;
        swapParams[0][1] = 0;
        swapParams[0][2] = 4;
        swapParams[0][3] = 0;
        swapParams[0][4] = 2;

        address[] memory pools = new address[](5);

        callData = abi.encodeWithSelector(
            ICurveFacet.exchange.selector,
            address(CURVE_ROUTER),
            route,
            swapParams,
            2000 * 10 ** 6,
            0,
            pools
        );
        actions[0] = abi.encode(address(vaultAddress), callData);

        IMulticallFacet(vaultAddress).submitActions(actions);
        console.log(IERC4626(vaultAddress).totalAssets());

        vm.stopPrank();

        vm.startPrank(CURATOR);
        callData = abi.encodeWithSelector(
            ICurveLiquidityGaugeV6Facet.depositCurveGaugeV6.selector,
            address(CURVE_GAUGE),
            IERC20(USDCxCrvUSD_CURVE_POOL).balanceOf(address(vaultAddress)) / 2
        );
        actions[0] = abi.encode(address(vaultAddress), callData);

        IMulticallFacet(vaultAddress).submitActions(actions);
        console.log(IERC4626(vaultAddress).totalAssets());

        vm.stopPrank();

        vm.warp(block.timestamp + 20);
        console.log(IERC4626(vaultAddress).totalAssets());
    }

    function _getPath(
        address tokenIn,
        address tokenOut
    ) internal pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        return path;
    }

    function _getCuts() internal view returns (IDiamondCut.FacetCut[] memory) {
        // selectors for diamond loupe
        bytes4[] memory functionSelectorsLoupeFacet = new bytes4[](5);
        functionSelectorsLoupeFacet[0] = IDiamondLoupe.facets.selector;
        functionSelectorsLoupeFacet[1] = IDiamondLoupe
            .facetFunctionSelectors
            .selector;
        functionSelectorsLoupeFacet[2] = IDiamondLoupe.facetAddresses.selector;
        functionSelectorsLoupeFacet[3] = IDiamondLoupe.facetAddress.selector;
        functionSelectorsLoupeFacet[4] = IERC165.supportsInterface.selector;

        // selectors for access control
        bytes4[] memory functionSelectorsAccessControlFacet = new bytes4[](9);
        functionSelectorsAccessControlFacet[0] = AccessControlFacet
            .transferCuratorship
            .selector;
        functionSelectorsAccessControlFacet[1] = AccessControlFacet
            .transferOwnership
            .selector;
        functionSelectorsAccessControlFacet[2] = AccessControlFacet
            .acceptOwnership
            .selector;
        functionSelectorsAccessControlFacet[3] = AccessControlFacet
            .transferGuardian
            .selector;
        functionSelectorsAccessControlFacet[4] = AccessControlFacet
            .owner
            .selector;
        functionSelectorsAccessControlFacet[5] = AccessControlFacet
            .pendingOwner
            .selector;
        functionSelectorsAccessControlFacet[6] = AccessControlFacet
            .curator
            .selector;
        functionSelectorsAccessControlFacet[7] = AccessControlFacet
            .guardian
            .selector;
        functionSelectorsAccessControlFacet[8] = AccessControlFacet
            .moreVaultsRegistry
            .selector;

        bytes memory initDataAccessControlFacet = abi.encode(
            OWNER,
            CURATOR,
            GUARDIAN
        );

        // selectors for configuration
        bytes4[] memory functionSelectorsConfigurationFacet = new bytes4[](14);
        functionSelectorsConfigurationFacet[0] = ConfigurationFacet
            .setFeeRecipient
            .selector;
        functionSelectorsConfigurationFacet[1] = ConfigurationFacet
            .setTimeLockPeriod
            .selector;
        functionSelectorsConfigurationFacet[2] = ConfigurationFacet
            .setDepositCapacity
            .selector;
        functionSelectorsConfigurationFacet[3] = ConfigurationFacet
            .addAvailableAsset
            .selector;
        functionSelectorsConfigurationFacet[4] = ConfigurationFacet
            .addAvailableAssets
            .selector;
        functionSelectorsConfigurationFacet[5] = ConfigurationFacet
            .enableAssetToDeposit
            .selector;
        functionSelectorsConfigurationFacet[6] = ConfigurationFacet
            .disableAssetToDeposit
            .selector;
        functionSelectorsConfigurationFacet[7] = ConfigurationFacet
            .isAssetAvailable
            .selector;
        functionSelectorsConfigurationFacet[8] = ConfigurationFacet
            .isAssetDepositable
            .selector;
        functionSelectorsConfigurationFacet[9] = ConfigurationFacet
            .getAvailableAssets
            .selector;
        functionSelectorsConfigurationFacet[10] = ConfigurationFacet
            .fee
            .selector;
        functionSelectorsConfigurationFacet[11] = ConfigurationFacet
            .depositCapacity
            .selector;
        functionSelectorsConfigurationFacet[12] = ConfigurationFacet
            .timeLockPeriod
            .selector;
        functionSelectorsConfigurationFacet[13] = ConfigurationFacet
            .feeRecipient
            .selector;
        bytes memory initDataConfigurationFacet = abi.encode(
            address(factory),
            address(registry)
        );

        // selectors for multicall
        bytes4[] memory functionSelectorsMulticallFacet = new bytes4[](5);
        functionSelectorsMulticallFacet[0] = MulticallFacet
            .submitActions
            .selector;
        functionSelectorsMulticallFacet[1] = MulticallFacet
            .executeActions
            .selector;
        functionSelectorsMulticallFacet[2] = MulticallFacet
            .vetoActions
            .selector;
        functionSelectorsMulticallFacet[3] = MulticallFacet
            .getPendingActions
            .selector;
        functionSelectorsMulticallFacet[4] = MulticallFacet
            .getCurrentNonce
            .selector;
        bytes memory initDataMulticallFacet = abi.encode(0, 1e50);

        // selectors for vault
        bytes4[] memory functionSelectorsVaultFacet = new bytes4[](30);
        functionSelectorsVaultFacet[0] = IERC20Metadata.name.selector;
        functionSelectorsVaultFacet[1] = IERC20Metadata.symbol.selector;
        functionSelectorsVaultFacet[2] = IERC20Metadata.decimals.selector;
        functionSelectorsVaultFacet[3] = IERC20.balanceOf.selector;
        functionSelectorsVaultFacet[4] = IERC20.approve.selector;
        functionSelectorsVaultFacet[5] = IERC20.transfer.selector;
        functionSelectorsVaultFacet[6] = IERC20.transferFrom.selector;
        functionSelectorsVaultFacet[7] = IERC20.allowance.selector;
        functionSelectorsVaultFacet[8] = IERC20.totalSupply.selector;
        functionSelectorsVaultFacet[9] = IERC4626.asset.selector;
        functionSelectorsVaultFacet[10] = IERC4626.totalAssets.selector;
        functionSelectorsVaultFacet[11] = IERC4626.convertToAssets.selector;
        functionSelectorsVaultFacet[12] = IERC4626.convertToShares.selector;
        functionSelectorsVaultFacet[13] = IERC4626.maxDeposit.selector;
        functionSelectorsVaultFacet[14] = IERC4626.previewDeposit.selector;
        functionSelectorsVaultFacet[15] = IERC4626.deposit.selector;
        functionSelectorsVaultFacet[16] = IERC4626.maxMint.selector;
        functionSelectorsVaultFacet[17] = IERC4626.previewMint.selector;
        functionSelectorsVaultFacet[18] = IERC4626.mint.selector;
        functionSelectorsVaultFacet[19] = IERC4626.maxWithdraw.selector;
        functionSelectorsVaultFacet[20] = IERC4626.previewWithdraw.selector;
        functionSelectorsVaultFacet[21] = IERC4626.withdraw.selector;
        functionSelectorsVaultFacet[22] = IERC4626.maxRedeem.selector;
        functionSelectorsVaultFacet[23] = IERC4626.previewRedeem.selector;
        functionSelectorsVaultFacet[24] = IERC4626.redeem.selector;
        // Multi-token deposit function
        functionSelectorsVaultFacet[25] = bytes4(
            keccak256("deposit(address[],uint256[],address)")
        );
        functionSelectorsVaultFacet[26] = IVaultFacet.paused.selector;
        functionSelectorsVaultFacet[27] = IVaultFacet.pause.selector;
        functionSelectorsVaultFacet[28] = IVaultFacet.unpause.selector;
        functionSelectorsVaultFacet[29] = IVaultFacet.setFee.selector;

        bytes memory initDataVaultFacet = abi.encode(
            VAULT_NAME,
            VAULT_SYMBOL,
            WETH,
            FEE_RECIPIENT,
            100,
            1000000 ether
        );

        // selectors for uniswap v2
        bytes4[] memory functionSelectorsUniswapV2Facet = new bytes4[](15);
        functionSelectorsUniswapV2Facet[0] = IUniswapV2Facet
            .accountingUniswapV2Facet
            .selector;
        functionSelectorsUniswapV2Facet[1] = IUniswapV2Facet
            .addLiquidity
            .selector;
        functionSelectorsUniswapV2Facet[2] = IUniswapV2Facet
            .addLiquidityETH
            .selector;
        functionSelectorsUniswapV2Facet[3] = IUniswapV2Facet
            .removeLiquidity
            .selector;
        functionSelectorsUniswapV2Facet[4] = IUniswapV2Facet
            .removeLiquidityETH
            .selector;
        functionSelectorsUniswapV2Facet[5] = IUniswapV2Facet
            .swapExactTokensForTokens
            .selector;
        functionSelectorsUniswapV2Facet[6] = IUniswapV2Facet
            .swapTokensForExactTokens
            .selector;
        functionSelectorsUniswapV2Facet[7] = IUniswapV2Facet
            .swapExactETHForTokens
            .selector;
        functionSelectorsUniswapV2Facet[8] = IUniswapV2Facet
            .swapTokensForExactETH
            .selector;
        functionSelectorsUniswapV2Facet[9] = IUniswapV2Facet
            .swapExactTokensForETH
            .selector;
        functionSelectorsUniswapV2Facet[10] = IUniswapV2Facet
            .swapETHForExactTokens
            .selector;
        functionSelectorsUniswapV2Facet[11] = IUniswapV2Facet
            .removeLiquidityETHSupportingFeeOnTransferTokens
            .selector;
        functionSelectorsUniswapV2Facet[12] = IUniswapV2Facet
            .swapExactTokensForTokensSupportingFeeOnTransferTokens
            .selector;
        functionSelectorsUniswapV2Facet[13] = IUniswapV2Facet
            .swapExactETHForTokensSupportingFeeOnTransferTokens
            .selector;
        functionSelectorsUniswapV2Facet[14] = IUniswapV2Facet
            .swapExactTokensForETHSupportingFeeOnTransferTokens
            .selector;

        bytes32 facetSelectorUniswapV2 = bytes4(
            keccak256(abi.encodePacked("accountingUniswapV2Facet()"))
        );
        bytes memory initDataUniswapV2Facet = abi.encode(
            facetSelectorUniswapV2
        );

        // selectors for origami
        bytes4[] memory functionSelectorsMORELeverageFacet = new bytes4[](9);
        functionSelectorsMORELeverageFacet[0] = IMORELeverageFacet
            .accountingMORELeverageFacet
            .selector;
        functionSelectorsMORELeverageFacet[1] = IMORELeverageFacet
            .investWithToken
            .selector;
        functionSelectorsMORELeverageFacet[2] = IMORELeverageFacet
            .investWithNative
            .selector;
        functionSelectorsMORELeverageFacet[3] = IMORELeverageFacet
            .exitToToken
            .selector;
        functionSelectorsMORELeverageFacet[4] = IMORELeverageFacet
            .exitToNative
            .selector;
        functionSelectorsMORELeverageFacet[5] = IMORELeverageFacet
            .rebalanceUp
            .selector;
        functionSelectorsMORELeverageFacet[6] = IMORELeverageFacet
            .forceRebalanceUp
            .selector;
        functionSelectorsMORELeverageFacet[7] = IMORELeverageFacet
            .rebalanceDown
            .selector;
        functionSelectorsMORELeverageFacet[8] = IMORELeverageFacet
            .forceRebalanceDown
            .selector;

        bytes32 facetSelectorMORELeverage = bytes4(
            keccak256(abi.encodePacked("accountingMORELeverageFacet()"))
        );
        bytes memory initDataMORELeverageFacet = abi.encode(
            facetSelectorMORELeverage
        );

        // selectors for more markets
        bytes4[] memory functionSelectorsAaveV3Facet = new bytes4[](13);
        functionSelectorsAaveV3Facet[0] = IAaveV3Facet
            .accountingAaveV3Facet
            .selector;
        functionSelectorsAaveV3Facet[1] = IAaveV3Facet.supply.selector;
        functionSelectorsAaveV3Facet[2] = IAaveV3Facet.withdraw.selector;
        functionSelectorsAaveV3Facet[3] = IAaveV3Facet.borrow.selector;
        functionSelectorsAaveV3Facet[4] = IAaveV3Facet.repay.selector;
        functionSelectorsAaveV3Facet[5] = IAaveV3Facet
            .repayWithATokens
            .selector;
        functionSelectorsAaveV3Facet[6] = IAaveV3Facet
            .swapBorrowRateMode
            .selector;
        functionSelectorsAaveV3Facet[7] = IAaveV3Facet
            .rebalanceStableBorrowRate
            .selector;
        functionSelectorsAaveV3Facet[8] = IAaveV3Facet
            .setUserUseReserveAsCollateral
            .selector;
        functionSelectorsAaveV3Facet[9] = IAaveV3Facet.flashLoan.selector;
        functionSelectorsAaveV3Facet[10] = IAaveV3Facet
            .flashLoanSimple
            .selector;
        functionSelectorsAaveV3Facet[11] = IAaveV3Facet.setUserEMode.selector;
        functionSelectorsAaveV3Facet[12] = IAaveV3Facet
            .claimAllRewards
            .selector;

        bytes32 facetSelectorAaveV3 = bytes4(
            keccak256(abi.encodePacked("accountingAaveV3Facet()"))
        );
        bytes memory initDataAaveV3Facet = abi.encode(facetSelectorAaveV3);

        // selectors for izumi swap
        bytes4[] memory functionSelectorsIzumiSwapFacet = new bytes4[](2);
        functionSelectorsIzumiSwapFacet[0] = IIzumiSwapFacet
            .swapAmount
            .selector;
        functionSelectorsIzumiSwapFacet[1] = IIzumiSwapFacet
            .swapDesire
            .selector;

        // selectors for aggro kitty swap
        bytes4[] memory functionSelectorsAggroKittySwapFacet = new bytes4[](3);
        functionSelectorsAggroKittySwapFacet[0] = IAggroKittySwapFacet
            .swapNoSplit
            .selector;
        functionSelectorsAggroKittySwapFacet[1] = IAggroKittySwapFacet
            .swapNoSplitFromNative
            .selector;
        functionSelectorsAggroKittySwapFacet[2] = IAggroKittySwapFacet
            .swapNoSplitToNative
            .selector;

        // selectors for curve
        bytes4[] memory functionSelectorsCurveFacet = new bytes4[](3);
        functionSelectorsCurveFacet[0] = ICurveFacet.exchangeNg.selector;
        functionSelectorsCurveFacet[1] = ICurveFacet.exchange.selector;
        functionSelectorsCurveFacet[2] = ICurveFacet
            .accountingCurveFacet
            .selector;

        bytes32 facetSelectorCurve = bytes4(
            keccak256(abi.encodePacked("accountingCurveFacet()"))
        );
        bytes memory initDataCurveFacet = abi.encode(
            address(curve),
            facetSelectorCurve
        );

        // selectors for UniswapV3
        bytes4[] memory functionSelectorsUniswapV3Facet = new bytes4[](4);
        functionSelectorsUniswapV3Facet[0] = IUniswapV3Facet
            .exactInput
            .selector;
        functionSelectorsUniswapV3Facet[1] = IUniswapV3Facet
            .exactInputSingle
            .selector;
        functionSelectorsUniswapV3Facet[2] = IUniswapV3Facet
            .exactOutput
            .selector;
        functionSelectorsUniswapV3Facet[3] = IUniswapV3Facet
            .exactOutputSingle
            .selector;

        // selectors for MultiRewardsFacet
        bytes4[] memory functionSelectorsMultiRewardsFacet = new bytes4[](5);
        functionSelectorsMultiRewardsFacet[0] = IMultiRewardsFacet
            .accountingMultiRewardsFacet
            .selector;
        functionSelectorsMultiRewardsFacet[1] = IMultiRewardsFacet
            .stake
            .selector;
        functionSelectorsMultiRewardsFacet[2] = IMultiRewardsFacet
            .withdraw
            .selector;
        functionSelectorsMultiRewardsFacet[3] = IMultiRewardsFacet
            .getReward
            .selector;
        functionSelectorsMultiRewardsFacet[4] = IMultiRewardsFacet
            .exit
            .selector;
        bytes32 facetSelectorMultiRewards = bytes4(
            keccak256(abi.encodePacked("accountingMultiRewardsFacet()"))
        );
        bytes memory initDataMultiRewardsFacet = abi.encode(
            facetSelectorMultiRewards
        );

        // selectors for CurveLiquidityGaugeV6Facet
        bytes4[]
            memory functionSelectorsCurveLiquidityGaugeV6Facet = new bytes4[](
                5
            );
        functionSelectorsCurveLiquidityGaugeV6Facet[
            0
        ] = ICurveLiquidityGaugeV6Facet
            .accountingCurveLiquidityGaugeV6Facet
            .selector;
        functionSelectorsCurveLiquidityGaugeV6Facet[
            1
        ] = ICurveLiquidityGaugeV6Facet.depositCurveGaugeV6.selector;
        functionSelectorsCurveLiquidityGaugeV6Facet[
            2
        ] = ICurveLiquidityGaugeV6Facet.withdrawCurveGaugeV6.selector;
        functionSelectorsCurveLiquidityGaugeV6Facet[
            3
        ] = ICurveLiquidityGaugeV6Facet.claimRewardsCurveGaugeV6.selector;
        functionSelectorsCurveLiquidityGaugeV6Facet[
            4
        ] = ICurveLiquidityGaugeV6Facet.mintCRV.selector;

        bytes32 facetSelectorCurveLiquidityGaugeV6 = bytes4(
            keccak256(
                abi.encodePacked("accountingCurveLiquidityGaugeV6Facet()")
            )
        );
        bytes memory initDataCurveLiquidityGaugeV6Facet = abi.encode(
            address(curveGaugeV6),
            address(crvMinter),
            facetSelectorCurveLiquidityGaugeV6
        );

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](14);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsLoupeFacet,
            initData: ""
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(accessControl),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsAccessControlFacet,
            initData: initDataAccessControlFacet
        });
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(configuration),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsConfigurationFacet,
            initData: initDataConfigurationFacet
        });
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(multicall),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsMulticallFacet,
            initData: initDataMulticallFacet
        });
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(vault),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsVaultFacet,
            initData: initDataVaultFacet
        });
        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: address(uniswapV2),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsUniswapV2Facet,
            initData: initDataUniswapV2Facet
        });
        cuts[6] = IDiamondCut.FacetCut({
            facetAddress: address(origami),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsMORELeverageFacet,
            initData: initDataMORELeverageFacet
        });
        cuts[7] = IDiamondCut.FacetCut({
            facetAddress: address(moreMarkets),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsAaveV3Facet,
            initData: initDataAaveV3Facet
        });
        cuts[8] = IDiamondCut.FacetCut({
            facetAddress: address(izumiSwap),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsIzumiSwapFacet,
            initData: ""
        });
        cuts[9] = IDiamondCut.FacetCut({
            facetAddress: address(aggroKittySwap),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsAggroKittySwapFacet,
            initData: ""
        });
        cuts[10] = IDiamondCut.FacetCut({
            facetAddress: address(curve),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsCurveFacet,
            initData: initDataCurveFacet
        });
        cuts[11] = IDiamondCut.FacetCut({
            facetAddress: address(uniswapV3),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsUniswapV3Facet,
            initData: ""
        });
        cuts[12] = IDiamondCut.FacetCut({
            facetAddress: address(multiRewards),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsMultiRewardsFacet,
            initData: initDataMultiRewardsFacet
        });
        cuts[13] = IDiamondCut.FacetCut({
            facetAddress: address(curveGaugeV6),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectorsCurveLiquidityGaugeV6Facet,
            initData: initDataCurveLiquidityGaugeV6Facet
        });

        return cuts;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Minimal interfaces for Uniswap V2–style routers, factories, pairs, and ERC20 tokens.
interface IUniswapV2Router02 {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
}

/// @notice Interface for V2 forks that use NATIVE instead of ETH naming (e.g., some Monad forks)
interface IV2RouterNative {
    function swapExactNATIVEForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    function swapExactTokensForNATIVE(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactNATIVEForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForNATIVESupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/// @notice Uniswap V3 Interfaces
interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IUniswapV3Pool {
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
    function liquidity() external view returns (uint128);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function observe(uint32[] calldata secondsAgos) external view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
    function tickSpacing() external view returns (int24);
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint) external;
    function approve(address spender, uint amount) external returns (bool);
    function transfer(address to, uint amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint);
}

/// @notice FullMath library for safe overflow handling
library FullMath {
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        uint256 prod0;
        uint256 prod1;
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        if (prod1 == 0) {
            require(denominator > 0, "FullMath: denominator is zero");
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        require(denominator > prod1, "FullMath: overflow");

        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        uint256 twos = denominator & (~denominator + 1);
        assembly {
            denominator := div(denominator, twos)
        }

        assembly {
            prod0 := div(prod0, twos)
        }
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        uint256 inverse = (3 * denominator) ^ 2;
        inverse *= 2 - denominator * inverse;
        inverse *= 2 - denominator * inverse;
        inverse *= 2 - denominator * inverse;
        inverse *= 2 - denominator * inverse;
        inverse *= 2 - denominator * inverse;
        inverse *= 2 - denominator * inverse;

        result = prod0 * inverse;
        return result;
    }
}

/// @notice FixedPoint96 library
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}

/// @notice Interface for V2 forks that use NATIVE instead of ETH naming
interface IUniswapV2RouterNative {
    function swapExactNATIVEForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    function swapExactTokensForNATIVE(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactNATIVEForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForNATIVESupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

/// @title MonBridgeDex
/// @notice Production-grade DEX aggregator with Uniswap V2 and V3 support
/// @dev Enhanced with multi-intermediate token hopping, aggressive split optimization, and arbitrage detection
contract MonBridgeDex {
    address public owner;
    address[] public routersV2;
    address[] public routersV3;
    mapping(address => bool) public isRouterV2;
    mapping(address => bool) public isRouterV3;
    mapping(address => address) public v3RouterToFactory;
    uint public constant MAX_ROUTERS = 100;
    uint public feeAccumulatedETH;
    mapping(address => uint) public feeAccumulatedTokens;

    uint public constant FEE_DIVISOR = 1000; // 0.1% fee

    address public WETH;

    // Intermediate tokens for multi-hop routing (WETH + USDC + others)
    address[] public intermediateTokens;
    mapping(address => bool) public isIntermediateToken;
    uint public constant MAX_INTERMEDIATE_TOKENS = 10;

    // Router capability flags for different swap function signatures
    mapping(address => bool) public usesNativeNaming; // Uses swapExactNATIVEForTokens instead of ETH

    bool private _locked;
    bool public paused;

    // Router health tracking
    struct RouterInfo {
        bool isActive;
        uint256 lastSuccessfulSwap;
        uint256 failureCount;
        uint256 totalVolume;
    }
    mapping(address => RouterInfo) public routerInfo;
    uint256 public constant MAX_FAILURES_BEFORE_DISABLE = 10;

    // Slippage configuration
    struct SlippageConfig {
        uint16 baseSlippageBPS;
        uint16 impactMultiplier;
        uint16 maxSlippageBPS;
    }
    SlippageConfig public slippageConfig;

    // Liquidity validation config
    struct LiquidityConfig {
        uint256 minLiquidityUSD;
        bool requireLiquidityCheck;
    }
    LiquidityConfig public liquidityConfig;

    // TWAP oracle config for flash loan protection
    struct TWAPConfig {
        uint32 twapInterval;
        uint16 maxPriceDeviationBPS;
        bool enableTWAPCheck;
    }
    TWAPConfig public twapConfig;

    // Split trade configuration
    struct SplitConfig {
        bool enableAutoSplit;
        uint16 minSplitImpactBPS; // Minimum impact to trigger split (e.g., 10 = 0.1%)
        uint8 maxSplits; // Max number of splits (2-4)
        bool alwaysSplit; // If true, always try to split regardless of impact
        bool enableIntraRouterSplit; // Enable splitting within same router across fee tiers
    }
    SplitConfig public splitConfig;

    // Enhanced split quote for intra-router optimization
    struct FeeTierQuote {
        uint24 feeTier;
        address[] path;
        uint256 amountOut;
        uint256 priceImpact;
        uint256 liquidity;
    }

    // Fee-on-transfer token tracking
    mapping(address => bool) public isFeeOnTransferToken;
    mapping(address => uint256) public lastKnownTransferFee;

    // Token blacklist
    mapping(address => bool) public tokenBlacklist;

    modifier nonReentrant() {
        require(!_locked, "Reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier validTokens(address[] calldata path) {
        for (uint i = 0; i < path.length; i++) {
            require(!tokenBlacklist[path[i]], "Token blacklisted");
        }
        _;
    }

    enum SwapType {
        ETH_TO_TOKEN,
        TOKEN_TO_ETH,
        TOKEN_TO_TOKEN
    }

    enum RouterType {
        V2,
        V3
    }

    struct SwapData {
        SwapType swapType;
        RouterType routerType;
        address router;
        address[] path; // Full path for both V2 and V3 (V2 supports any length, V3 encoded separately)
        uint24[] v3Fees; // For multi-hop V3
        uint amountIn;
        uint amountOutMin;
        uint deadline;
        bool supportFeeOnTransfer;
    }

    struct SplitSwapData {
        SwapData[] splits;
        uint totalAmountIn;
        uint totalAmountOutMin;
        uint16[] splitPercentages; // basis points (e.g., 5000 = 50%)
    }

    struct RouterQuote {
        address router;
        RouterType routerType;
        uint24 v3Fee;
        uint amountOut;
        uint priceImpact;
        address[] path;
    }

    // Enhanced quote structure for per-router internal optimization
    struct EnhancedRouterQuote {
        address router;
        RouterType routerType;
        uint totalAmountOut;
        uint totalPriceImpact;
        InternalSplit[] internalSplits; // Multiple paths/fees within same router
    }

    // Internal split within a single router (different fee tiers or paths)
    struct InternalSplit {
        address[] path;
        uint24[] v3Fees;
        uint16 percentageBPS; // Percentage of this router's allocation
        uint amountOut;
        uint priceImpact;
    }

    // Aggregated router strategy for split optimization
    struct RouterStrategy {
        address router;
        RouterType routerType;
        uint16 allocationBPS; // Percentage of total trade
        InternalSplit[] internalSplits;
        uint expectedOutput;
        uint averageImpact;
    }

    uint24[] public v3FeeTiers;

    event RouterV2Added(address router);
    event RouterV2Removed(address router);
    event RouterV3Added(address router, address factory);
    event RouterV3Removed(address router);
    event SwapExecuted(
        address indexed user,
        address indexed router,
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOut,
        uint fee,
        uint actualSlippage,
        SwapType swapType
    );
    event SplitSwapExecuted(
        address indexed user,
        address tokenIn,
        address tokenOut,
        uint totalAmountIn,
        uint totalAmountOut,
        uint splitCount,
        uint totalFee
    );
    event FeesWithdrawn(address indexed owner, uint ethAmount);
    event TokenFeesWithdrawn(address indexed owner, address token, uint amount);
    event PriceImpactWarning(address indexed user, uint priceImpact, uint threshold);
    event RouterHealthUpdate(address indexed router, bool isActive, uint failureCount);

    constructor(address _weth, address _usdc) {
        owner = msg.sender;
        WETH = _weth;
        // Standard Uniswap V3 fee tiers (most common first for optimization)
        v3FeeTiers.push(3000);   // 0.30% - most common for volatile pairs
        v3FeeTiers.push(500);    // 0.05% - common for stable-ish pairs
        v3FeeTiers.push(100);    // 0.01% - stable pairs (USDC/USDT)
        v3FeeTiers.push(10000);  // 1.00% - exotic/low liquidity pairs

        // Additional fee tiers (less common but used by some DEXs)
        v3FeeTiers.push(50);     // 0.005% - ultra-stable pairs (rare)
        v3FeeTiers.push(250);    // 0.025% - between stable and standard
        v3FeeTiers.push(2500);   // 0.25% - between 0.05% and 0.30%
        v3FeeTiers.push(5000);   // 0.50% - between 0.30% and 1.00%

        // Initialize intermediate tokens with WETH and USDC
        intermediateTokens.push(_weth);
        isIntermediateToken[_weth] = true;
        if (_usdc != address(0)) {
            intermediateTokens.push(_usdc);
            isIntermediateToken[_usdc] = true;
        }

        slippageConfig = SlippageConfig({
            baseSlippageBPS: 50,
            impactMultiplier: 150,
            maxSlippageBPS: 500
        });

        liquidityConfig = LiquidityConfig({
            minLiquidityUSD: 1e6,
            requireLiquidityCheck: false
        });

        twapConfig = TWAPConfig({
            twapInterval: 1800,
            maxPriceDeviationBPS: 500,
            enableTWAPCheck: true
        });

        splitConfig = SplitConfig({
            enableAutoSplit: true,
            minSplitImpactBPS: 10, // Split if impact > 0.1% (very aggressive)
            maxSplits: 4,
            alwaysSplit: true, // Always try to split for best execution
            enableIntraRouterSplit: true // Enable fee tier distribution within router
        });
    }

    /// @notice Add a V2 router
    function addRouter(address _router) external onlyOwner {
        require(_router != address(0), "Invalid router address");
        require(!isRouterV2[_router], "Router already added");
        require(routersV2.length < MAX_ROUTERS, "Max routers reached");
        routersV2.push(_router);
        isRouterV2[_router] = true;
        routerInfo[_router].isActive = true;
        emit RouterV2Added(_router);
    }

    /// @notice Add multiple V2 routers
    function addRouters(address[] calldata _routers) external onlyOwner {
        for (uint i = 0; i < _routers.length; i++) {
            require(_routers[i] != address(0), "Invalid router address");
            require(!isRouterV2[_routers[i]], "Router already added");
            require(routersV2.length < MAX_ROUTERS, "Max routers reached");
            routersV2.push(_routers[i]);
            isRouterV2[_routers[i]] = true;
            routerInfo[_routers[i]].isActive = true;
            emit RouterV2Added(_routers[i]);
        }
    }

    /// @notice Add a V3 router with its factory
    function addV3Router(address _router, address _factory) external onlyOwner {
        require(_router != address(0), "Invalid router address");
        require(_factory != address(0), "Invalid factory address");
        require(!isRouterV3[_router], "V3 Router already added");
        require(routersV3.length < MAX_ROUTERS, "Max routers reached");
        routersV3.push(_router);
        isRouterV3[_router] = true;
        v3RouterToFactory[_router] = _factory;
        routerInfo[_router].isActive = true;
        emit RouterV3Added(_router, _factory);
    }

    /// @notice Add multiple V3 routers with their factories
    function addV3Routers(address[] calldata _routers, address[] calldata _factories) external onlyOwner {
        require(_routers.length == _factories.length, "Arrays length mismatch");
        for (uint i = 0; i < _routers.length; i++) {
            require(_routers[i] != address(0), "Invalid router address");
            require(_factories[i] != address(0), "Invalid factory address");
            require(!isRouterV3[_routers[i]], "V3 Router already added");
            require(routersV3.length < MAX_ROUTERS, "Max routers reached");
            routersV3.push(_routers[i]);
            isRouterV3[_routers[i]] = true;
            v3RouterToFactory[_routers[i]] = _factories[i];
            routerInfo[_routers[i]].isActive = true;
            emit RouterV3Added(_routers[i], _factories[i]);
        }
    }

    /// @notice Remove a V2 router
    function removeRouter(address _router) external onlyOwner {
        require(isRouterV2[_router], "Router not found");
        for (uint i = 0; i < routersV2.length; i++) {
            if (routersV2[i] == _router) {
                routersV2[i] = routersV2[routersV2.length - 1];
                routersV2.pop();
                isRouterV2[_router] = false;
                routerInfo[_router].isActive = false;
                emit RouterV2Removed(_router);
                break;
            }
        }
    }

    /// @notice Remove multiple V2 routers
    function removeRouters(address[] calldata _routers) external onlyOwner {
        for (uint i = 0; i < _routers.length; i++) {
            if (isRouterV2[_routers[i]]) {
                for (uint j = 0; j < routersV2.length; j++) {
                    if (routersV2[j] == _routers[i]) {
                        routersV2[j] = routersV2[routersV2.length - 1];
                        routersV2.pop();
                        isRouterV2[_routers[i]] = false;
                        routerInfo[_routers[i]].isActive = false;
                        emit RouterV2Removed(_routers[i]);
                        break;
                    }
                }
            }
        }
    }

    /// @notice Remove a V3 router
    function removeV3Router(address _router) external onlyOwner {
        require(isRouterV3[_router], "V3 Router not found");
        for (uint i = 0; i < routersV3.length; i++) {
            if (routersV3[i] == _router) {
                routersV3[i] = routersV3[routersV3.length - 1];
                routersV3.pop();
                isRouterV3[_router] = false;
                routerInfo[_router].isActive = false;
                delete v3RouterToFactory[_router];
                emit RouterV3Removed(_router);
                break;
            }
        }
    }

    /// @notice Add an intermediate token for multi-hop routing
    function addIntermediateToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        require(!isIntermediateToken[_token], "Token already added");
        require(intermediateTokens.length < MAX_INTERMEDIATE_TOKENS, "Max intermediate tokens reached");
        intermediateTokens.push(_token);
        isIntermediateToken[_token] = true;
    }

    /// @notice Remove an intermediate token
    function removeIntermediateToken(address _token) external onlyOwner {
        require(isIntermediateToken[_token], "Token not found");
        require(_token != WETH, "Cannot remove WETH");
        for (uint i = 0; i < intermediateTokens.length; i++) {
            if (intermediateTokens[i] == _token) {
                intermediateTokens[i] = intermediateTokens[intermediateTokens.length - 1];
                intermediateTokens.pop();
                isIntermediateToken[_token] = false;
                break;
            }
        }
    }

    /// @notice Get all intermediate tokens
    function getIntermediateTokens() external view returns (address[] memory) {
        return intermediateTokens;
    }

    /// @notice Set router capability - uses NATIVE naming convention
    function setRouterUsesNativeNaming(address _router, bool _usesNative) external onlyOwner {
        require(isRouterV2[_router], "Router not V2");
        usesNativeNaming[_router] = _usesNative;
    }

    /// @notice Get all V2 routers
    function getRouters() external view returns (address[] memory) {
        return routersV2;
    }

    /// @notice Get all V3 routers
    function getV3Routers() external view returns (address[] memory) {
        return routersV3;
    }

    /// @notice Get V2 routers count
    function getRoutersV2Count() external view returns (uint) {
        return routersV2.length;
    }

    /// @notice Get V3 routers count
    function getRoutersV3Count() external view returns (uint) {
        return routersV3.length;
    }

    /// @notice Get V3 fee tiers
    function getV3FeeTiers() external view returns (uint24[] memory) {
        return v3FeeTiers;
    }

    /// @notice Add a new V3 fee tier
    /// @dev Allows adding new fee tiers as DEXs introduce them
    /// @param feeTier The fee tier in hundredths of a bip (e.g., 3000 = 0.30%)
    function addV3FeeTier(uint24 feeTier) external onlyOwner {
        require(feeTier > 0 && feeTier <= 100000, "Invalid fee tier"); // Max 10%

        // Check if tier already exists
        for (uint i = 0; i < v3FeeTiers.length; i++) {
            require(v3FeeTiers[i] != feeTier, "Fee tier already exists");
        }

        v3FeeTiers.push(feeTier);
    }

    /// @notice Remove a V3 fee tier
    /// @param feeTier The fee tier to remove
    function removeV3FeeTier(uint24 feeTier) external onlyOwner {
        for (uint i = 0; i < v3FeeTiers.length; i++) {
            if (v3FeeTiers[i] == feeTier) {
                // Swap with last element and pop
                v3FeeTiers[i] = v3FeeTiers[v3FeeTiers.length - 1];
                v3FeeTiers.pop();
                return;
            }
        }
        revert("Fee tier not found");
    }

    /// @notice Get fee percentage in basis points
    function feePercent() external pure returns (uint) {
        return 10000 / FEE_DIVISOR; // Returns 10 (0.1% = 10 bps)
    }

    /// @notice Safe token approval with reset logic for non-standard tokens
    function _safeApprove(address token, address spender, uint256 amount) internal {
        // Check current allowance
        uint256 currentAllowance = IERC20(token).allowance(address(this), spender);

        // If allowance is already sufficient, no need to approve
        if (currentAllowance >= amount) {
            return;
        }

        // Some tokens (like USDT) require resetting allowance to 0 first
        if (currentAllowance > 0) {
            require(IERC20(token).approve(spender, 0), "Approval reset failed");
        }

        // Set new allowance
        require(IERC20(token).approve(spender, amount), "Approval failed");
    }

    /// @notice Normalize amount to target decimals for accurate comparisons
    /// @dev Handles USDC (6) vs DAI (18) and other decimal mismatches
    /// @param token Token address to get decimals from
    /// @param amount Amount to normalize
    /// @param targetDecimals Target decimal precision (usually 18)
    /// @return Normalized amount
    function _normalizeAmount(
        address token,
        uint256 amount,
        uint8 targetDecimals
    ) internal view returns (uint256) {
        uint8 tokenDecimals = IERC20(token).decimals();

        if (tokenDecimals == targetDecimals) {
            return amount;
        } else if (tokenDecimals > targetDecimals) {
            // Scale down (e.g., 18 -> 6)
            return amount / (10 ** (tokenDecimals - targetDecimals));
        } else {
            // Scale up (e.g., 6 -> 18)
            return amount * (10 ** (targetDecimals - tokenDecimals));
        }
    }

    /// @notice Compare two token amounts with different decimals
    /// @dev Normalizes both to 18 decimals before comparison
    /// @return 1 if amountA > amountB, -1 if amountA < amountB, 0 if equal
    function _compareAmounts(
        address tokenA,
        uint256 amountA,
        address tokenB,
        uint256 amountB
    ) internal view returns (int8) {
        uint256 normalizedA = _normalizeAmount(tokenA, amountA, 18);
        uint256 normalizedB = _normalizeAmount(tokenB, amountB, 18);

        if (normalizedA > normalizedB) return 1;
        if (normalizedA < normalizedB) return -1;
        return 0;
    }

    /// @notice Validate pool price against TWAP to prevent flash loan manipulation
    /// @dev Compares current spot price with TWAP over configured interval
    /// @param pool The V3 pool address to validate
    /// @param currentSqrtPriceX96 Current sqrt price from slot0
    /// @return isValid True if price deviation is within acceptable range
    function _validateTWAP(address pool, uint160 currentSqrtPriceX96) internal view returns (bool) {
        if (!twapConfig.enableTWAPCheck) return true;
        if (pool == address(0) || currentSqrtPriceX96 == 0) return false;

        // Query TWAP from V3 pool observations
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapConfig.twapInterval; // e.g., 300 seconds ago
        secondsAgos[1] = 0; // now

        try IUniswapV3Pool(pool).observe(secondsAgos) returns (
            int56[] memory tickCumulatives,
            uint160[] memory
        ) {
            // Calculate average tick over the interval with proper rounding
            int56 tickDiff = tickCumulatives[1] - tickCumulatives[0];
            int56 interval = int56(uint56(twapConfig.twapInterval));

            // Proper rounding for negative tick differences (round towards negative infinity)
            int24 avgTick;
            if (tickDiff < 0 && (tickDiff % interval != 0)) {
                avgTick = int24((tickDiff / interval) - 1);
            } else {
                avgTick = int24(tickDiff / interval);
            }

            // Get current tick from slot0
            int24 currentTick;
            try IUniswapV3Pool(pool).slot0() returns (
                uint160,
                int24 tick,
                uint16,
                uint16,
                uint16,
                uint8,
                bool
            ) {
                currentTick = tick;
            } catch {
                return false;
            }

            // Calculate tick deviation as a proxy for price deviation
            // Each tick represents ~0.01% price change
            int24 tickDeviation = currentTick > avgTick ? currentTick - avgTick : avgTick - currentTick;

            // Convert maxPriceDeviationBPS to tick deviation
            // 1 BPS = 0.01%, 1 tick = ~0.01% price change
            // So maxPriceDeviationBPS maps roughly to max tick deviation
            int24 maxTickDeviation = int24(uint24(twapConfig.maxPriceDeviationBPS));

            return tickDeviation <= maxTickDeviation;
        } catch {
            // If TWAP query fails (insufficient observations), allow swap but log warning
            // This prevents blocking swaps on new pools
            return true;
        }
    }

    /// @notice Get TWAP price for a V3 pool with proper rounding
    /// @param pool The V3 pool address
    /// @param twapInterval Time interval in seconds for TWAP calculation
    /// @return twapTick The time-weighted average tick (properly rounded)
    function _getTWAPTick(address pool, uint32 twapInterval) internal view returns (int24 twapTick) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapInterval;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(pool).observe(secondsAgos);
        int56 tickDiff = tickCumulatives[1] - tickCumulatives[0];
        int56 interval = int56(uint56(twapInterval));

        // Proper rounding for negative tick differences (round towards negative infinity)
        // This matches Uniswap's OracleLibrary implementation
        if (tickDiff < 0 && (tickDiff % interval != 0)) {
            twapTick = int24((tickDiff / interval) - 1);
        } else {
            twapTick = int24(tickDiff / interval);
        }
    }

    /// @notice Validate pool liquidity meets minimum requirements
    function _validateLiquidity(uint128 liquidity) internal view returns (bool) {
        if (!liquidityConfig.requireLiquidityCheck) return true;

        // Simplified check - in production would convert to USD value
        return liquidity >= uint128(liquidityConfig.minLiquidityUSD);
    }

    /// @notice Calculate V3 swap output with accurate liquidity-based price impact
    /// @dev Uses actual liquidity to calculate real price impact from swap
    /// @dev Fixed overflow handling for tokens with different decimals (18->6, 8->6, etc.)
    /// @param pool V3 pool address
    /// @param amountIn Input amount
    /// @param tokenIn Input token address
    /// @param feeTier Pool fee tier (e.g., 500, 3000, 10000)
    /// @return amountOut Expected output amount after the swap
    /// @return priceImpact Price impact in basis points (100 = 1%)
    function _calculateV3SwapOutput(
        address pool,
        uint256 amountIn,
        address tokenIn,
        uint24 feeTier
    ) internal view returns (uint256 amountOut, uint256 priceImpact) {
        if (pool == address(0) || amountIn == 0) return (0, type(uint256).max);

        try IUniswapV3Pool(pool).slot0() returns (
            uint160 sqrtPriceX96,
            int24,
            uint16,
            uint16,
            uint16,
            uint8,
            bool
        ) {
            uint128 liquidity;
            try IUniswapV3Pool(pool).liquidity() returns (uint128 liq) {
                liquidity = liq;
            } catch {
                return (0, type(uint256).max);
            }

            if (liquidity == 0 || sqrtPriceX96 == 0) return (0, type(uint256).max);

            // Validate TWAP if enabled (flash loan protection)
            if (!_validateTWAP(pool, sqrtPriceX96)) {
                return (0, type(uint256).max);
            }

            address token0;
            address token1;

            try IUniswapV3Pool(pool).token0() returns (address t0) {
                token0 = t0;
            } catch {
                return (0, type(uint256).max);
            }

            try IUniswapV3Pool(pool).token1() returns (address t1) {
                token1 = t1;
            } catch {
                return (0, type(uint256).max);
            }

            bool zeroForOne = tokenIn == token0;

            // Calculate fee - use safe math to prevent overflow
            uint256 feeAmount = FullMath.mulDiv(amountIn, uint256(feeTier), 1000000);
            uint256 amountInAfterFee = amountIn - feeAmount;

            // Get decimals for proper scaling - handle decimal mismatches
            uint8 decimals0 = 18; // default
            uint8 decimals1 = 18; // default
            try IERC20(token0).decimals() returns (uint8 d) { decimals0 = d; } catch {}
            try IERC20(token1).decimals() returns (uint8 d) { decimals1 = d; } catch {}

            // Calculate output at SPOT PRICE (no slippage - ideal output)
            // Use FullMath consistently to prevent overflow with different decimals
            uint256 spotOutput;
            if (zeroForOne) {
                // token0 -> token1: multiply by price
                // price = (sqrtPriceX96)^2 / Q96^2
                // For token0 -> token1, we need to multiply by price
                uint256 sqrtPrice = uint256(sqrtPriceX96);

                // Scale for decimal differences to prevent overflow
                uint256 scaledAmount = amountInAfterFee;
                if (decimals0 > decimals1) {
                    // Scaling down (e.g., 18 -> 6): divide first to prevent overflow
                    uint256 decimalDiff = decimals0 - decimals1;
                    if (decimalDiff <= 18) {
                        scaledAmount = amountInAfterFee / (10 ** decimalDiff);
                    }
                }

                // Use FullMath for safe multiplication
                uint256 intermediate = FullMath.mulDiv(scaledAmount, sqrtPrice, FixedPoint96.Q96);
                spotOutput = FullMath.mulDiv(intermediate, sqrtPrice, FixedPoint96.Q96);

                // Scale back up if needed
                if (decimals1 > decimals0) {
                    uint256 decimalDiff = decimals1 - decimals0;
                    if (decimalDiff <= 18 && spotOutput < type(uint256).max / (10 ** decimalDiff)) {
                        spotOutput = spotOutput * (10 ** decimalDiff);
                    }
                }
            } else {
                // token1 -> token0: divide by price
                if (sqrtPriceX96 == 0) return (0, type(uint256).max);
                uint256 sqrtPrice = uint256(sqrtPriceX96);

                // Scale for decimal differences
                uint256 scaledAmount = amountInAfterFee;
                if (decimals1 > decimals0) {
                    uint256 decimalDiff = decimals1 - decimals0;
                    if (decimalDiff <= 18) {
                        scaledAmount = amountInAfterFee / (10 ** decimalDiff);
                    }
                }

                uint256 intermediate = FullMath.mulDiv(scaledAmount, FixedPoint96.Q96, sqrtPrice);
                spotOutput = FullMath.mulDiv(intermediate, FixedPoint96.Q96, sqrtPrice);

                // Scale back up if needed
                if (decimals0 > decimals1) {
                    uint256 decimalDiff = decimals0 - decimals1;
                    if (decimalDiff <= 18 && spotOutput < type(uint256).max / (10 ** decimalDiff)) {
                        spotOutput = spotOutput * (10 ** decimalDiff);
                    }
                }
            }

            // ACCURATE PRICE IMPACT CALCULATION using V3 concentrated liquidity model
            // Calculate the virtual reserves based on liquidity and current price
            // Virtual reserve0 = L / sqrtPrice, Virtual reserve1 = L * sqrtPrice
            // Use scaling to prevent overflow with large liquidity values

            uint256 virtualReserve0;
            uint256 virtualReserve1;

            // Scale down liquidity if too large to prevent overflow
            uint256 scaledLiquidity = uint256(liquidity);
            uint256 scaleFactor = 1;
            while (scaledLiquidity > type(uint128).max) {
                scaledLiquidity = scaledLiquidity / 1e6;
                scaleFactor = scaleFactor * 1e6;
            }

            virtualReserve0 = FullMath.mulDiv(scaledLiquidity, FixedPoint96.Q96, uint256(sqrtPriceX96));
            virtualReserve1 = FullMath.mulDiv(scaledLiquidity, uint256(sqrtPriceX96), FixedPoint96.Q96);

            // Scale back
            if (scaleFactor > 1) {
                if (virtualReserve0 < type(uint256).max / scaleFactor) {
                    virtualReserve0 = virtualReserve0 * scaleFactor;
                }
                if (virtualReserve1 < type(uint256).max / scaleFactor) {
                    virtualReserve1 = virtualReserve1 * scaleFactor;
                }
            }

            // Calculate actual output considering liquidity depth
            // Using constant product approximation with overflow protection
            if (zeroForOne) {
                // Swapping token0 for token1
                uint256 denominator = virtualReserve0 + amountInAfterFee;
                if (denominator == 0) return (0, type(uint256).max);

                // Use FullMath to prevent overflow
                amountOut = FullMath.mulDiv(amountInAfterFee, virtualReserve1, denominator);
            } else {
                // Swapping token1 for token0
                uint256 denominator = virtualReserve1 + amountInAfterFee;
                if (denominator == 0) return (0, type(uint256).max);

                amountOut = FullMath.mulDiv(amountInAfterFee, virtualReserve0, denominator);
            }

            // Validate we got a reasonable output
            if (amountOut == 0 || spotOutput == 0) {
                return (0, type(uint256).max);
            }

            // Calculate REAL price impact: (spotOutput - actualOutput) / spotOutput * 10000
            // This gives us basis points of slippage due to trade size vs liquidity
            if (spotOutput > amountOut) {
                // Use FullMath to prevent overflow in impact calculation
                priceImpact = FullMath.mulDiv(spotOutput - amountOut, 10000, spotOutput);
            } else {
                priceImpact = 0;
            }

            // Add fee tier contribution to price impact for routing decisions
            uint256 feeTierBPS = FullMath.mulDiv(uint256(feeTier), 10000, 1000000);
            priceImpact += feeTierBPS;

            return (amountOut, priceImpact);
        } catch {
            return (0, type(uint256).max);
        }
    }

    /// @notice Find best V3 pool with optimal fee tier selection
    /// @dev Prioritizes: 1) Net output after impact penalty, 2) Lower fee tier on ties
    /// @dev Returns address(0) if NO valid pool found - ensures we never return a failing pool
    function _getBestV3Pool(
        address factory,
        address tokenIn,
        address tokenOut,
        uint amountIn
    ) internal view returns (
        address bestPool,
        uint24 bestFee,
        uint bestAmountOut,
        uint bestImpact
    ) {
        bestAmountOut = 0;
        bestImpact = type(uint).max;
        bestPool = address(0);
        bestFee = 0;
        uint256 bestScore = 0;

        for (uint i = 0; i < v3FeeTiers.length; i++) {
            uint24 fee = v3FeeTiers[i];

            // Validate pool exists and has liquidity before attempting calculation
            if (!_v3PoolExists(factory, tokenIn, tokenOut, fee)) {
                continue;
            }

            address pool;
            try IUniswapV3Factory(factory).getPool(tokenIn, tokenOut, fee) returns (address p) {
                pool = p;
            } catch {
                continue;
            }

            if (pool == address(0)) continue;

            (uint amountOut, uint impact) = _calculateV3SwapOutput(pool, amountIn, tokenIn, fee);

            // Skip pools that return 0 or max impact (indicates calculation failed)
            if (amountOut == 0 || impact == type(uint256).max) continue;

            // Calculate score: amountOut - impact penalty
            // Higher impact = higher penalty
            uint256 impactPenalty = (amountOut * impact) / 10000;
            uint256 score = amountOut > impactPenalty ? amountOut - impactPenalty : 0;

            // Fallback: If penalty would zero the score but we have a valid amountOut,
            // use raw amountOut for comparison to avoid filtering out all pools
            // This ensures we always select the best available pool even with high impact
            if (score == 0 && amountOut > 0) {
                score = amountOut;
            }

            // Select best score, with lower fee tier as tie-breaker
            if (score > bestScore || (score == bestScore && fee < bestFee)) {
                bestScore = score;
                bestAmountOut = amountOut;
                bestPool = pool;
                bestFee = fee;
                bestImpact = impact;
            }
        }

        // bestPool will be address(0) if no valid pool was found
        // This allows caller to fall back to V2 or other options
    }

    /// @notice Validate router is active and healthy
    function _validateRouter(address router) internal view returns (bool) {
        RouterInfo memory info = routerInfo[router];

        if (!info.isActive) return false;
        if (info.failureCount >= MAX_FAILURES_BEFORE_DISABLE) return false;

        return true;
    }

    /// @notice Check if V2 pair exists for given tokens
    /// @dev Uniswap V2 stores pairs with sorted token addresses (token0 < token1)
    function _v2PairExists(address router, address tokenA, address tokenB) internal view returns (bool) {
        try IUniswapV2Router02(router).factory() returns (address factory) {
            if (factory == address(0)) return false;

            // Sort tokens to match Uniswap V2 factory storage
            (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

            try IUniswapV2Factory(factory).getPair(token0, token1) returns (address pair) {
                return pair != address(0);
            } catch {
                return false;
            }
        } catch {
            return false;
        }
    }

    /// @notice Validate V2 path exists (all pairs must exist)
    function _validateV2Path(address router, address[] memory path) internal view returns (bool) {
        if (path.length < 2) return false;

        for (uint i = 0; i < path.length - 1; i++) {
            if (!_v2PairExists(router, path[i], path[i + 1])) {
                return false;
            }
        }

        return true;
    }

    /// @notice Calculate accurate V2 price impact using constant product AMM formula
    /// @dev Uses router-reported amounts for per-hop impact calculation with overflow protection
    /// @param router V2 router address
    /// @param path Token path for the swap
    /// @param amountIn Input amount
    /// @return actualOutput The actual output amount after swap
    /// @return priceImpact Price impact in basis points (100 = 1%)
    function _calculateV2SwapOutput(
        address router,
        address[] memory path,
        uint256 amountIn
    ) internal view returns (uint256 actualOutput, uint256 priceImpact) {
        // Edge case: invalid input
        if (path.length < 2 || amountIn == 0) return (0, type(uint256).max);

        // Edge case: excessively large trade amounts (overflow protection)
        if (amountIn > type(uint112).max) return (0, type(uint256).max);

        try IUniswapV2Router02(router).factory() returns (address factory) {
            if (factory == address(0)) return (0, type(uint256).max);

            // Get actual output from router
            uint[] memory amounts;
            try IUniswapV2Router02(router).getAmountsOut(amountIn, path) returns (uint[] memory res) {
                amounts = res;
                actualOutput = amounts[amounts.length - 1];
            } catch {
                return (0, type(uint256).max);
            }

            if (actualOutput == 0) return (0, type(uint256).max);

            // Calculate per-hop price impact using router-reported amounts
            uint256 totalImpact = 0;

            for (uint i = 0; i < path.length - 1; i++) {
                address tokenIn = path[i];
                address tokenOut = path[i + 1];
                uint256 hopAmountIn = amounts[i];
                uint256 hopAmountOut = amounts[i + 1];

                // Get pair address
                address pair;
                try IUniswapV2Factory(factory).getPair(tokenIn, tokenOut) returns (address p) {
                    pair = p;
                } catch {
                    // CRITICAL: Return MAX impact on pair query failure (not 0)
                    return (0, type(uint256).max);
                }

                // Edge case: pair doesn't exist
                if (pair == address(0)) return (0, type(uint256).max);

                // Get reserves
                uint112 reserve0;
                uint112 reserve1;
                try IUniswapV2Pair(pair).getReserves() returns (uint112 r0, uint112 r1, uint32) {
                    reserve0 = r0;
                    reserve1 = r1;
                } catch {
                    return (0, type(uint256).max);
                }

                // Edge case: zero liquidity - return maximum impact
                if (reserve0 == 0 || reserve1 == 0) return (0, type(uint256).max);

                // Determine which reserve is for which token
                address token0;
                try IUniswapV2Pair(pair).token0() returns (address t0) {
                    token0 = t0;
                } catch {
                    return (0, type(uint256).max);
                }

                uint256 reserveIn;
                uint256 reserveOut;
                if (tokenIn == token0) {
                    reserveIn = uint256(reserve0);
                    reserveOut = uint256(reserve1);
                } else {
                    reserveIn = uint256(reserve1);
                    reserveOut = uint256(reserve0);
                }

                // Edge case: minimum liquidity check (avoid dust pools)
                uint256 MIN_LIQUIDITY = 1000;
                if (reserveIn < MIN_LIQUIDITY || reserveOut < MIN_LIQUIDITY) {
                    return (0, type(uint256).max);
                }

                // Edge case: trade would deplete more than 50% of reserves (extreme impact)
                if (hopAmountIn > reserveIn / 2) {
                    return (actualOutput, 5000); // Return 50% impact
                }

                // Calculate ideal output at spot price (no slippage)
                // Using FullMath to prevent overflow
                uint256 hopIdeal;
                if (hopAmountIn <= type(uint128).max && reserveOut <= type(uint128).max) {
                    hopIdeal = (hopAmountIn * reserveOut) / reserveIn;
                } else {
                    // Use FullMath for large numbers
                    hopIdeal = FullMath.mulDiv(hopAmountIn, reserveOut, reserveIn);
                }

                // Calculate per-hop impact: (idealOut - actualOut) / idealOut * 10000
                if (hopIdeal > hopAmountOut && hopIdeal > 0) {
                    uint256 hopImpact = ((hopIdeal - hopAmountOut) * 10000) / hopIdeal;
                    totalImpact += hopImpact;
                }
            }

            // Cap maximum impact at 10000 (100%)
            priceImpact = totalImpact > 10000 ? 10000 : totalImpact;
            return (actualOutput, priceImpact);
        } catch {
            return (0, type(uint256).max);
        }
    }

    /// @notice Check if V3 pool exists and has liquidity
    /// @dev Only checks pool existence and liquidity, avoiding strict checks that could exclude valid pools
    function _v3PoolExists(address factory, address tokenA, address tokenB, uint24 fee) internal view returns (bool) {
        if (factory == address(0)) return false;

        address pool;
        try IUniswapV3Factory(factory).getPool(tokenA, tokenB, fee) returns (address p) {
            pool = p;
        } catch {
            return false;
        }

        if (pool == address(0)) return false;

        // Check if pool has liquidity and slot0 is initialized
        try IUniswapV3Pool(pool).liquidity() returns (uint128 liquidity) {
            if (liquidity == 0) return false;

            // Also verify slot0 is accessible (pool is initialized)
            try IUniswapV3Pool(pool).slot0() returns (uint160 sqrtPrice, int24, uint16, uint16, uint16, uint8, bool) {
                return sqrtPrice > 0;
            } catch {
                return false;
            }
        } catch {
            return false;
        }
    }

    /// @notice Find best router (V2 or V3) with highest output and lowest price impact
    /// @dev Uses accurate price impact calculations for both V2 and V3
    function _getBestRouter(uint amountIn, address[] memory path) internal view returns (
        address bestRouter,
        uint bestAmountOut,
        RouterType bestRouterType,
        uint24[] memory bestV3Fees,
        uint bestPriceImpact,
        address[] memory bestPath
    ) {
        bestAmountOut = 0;
        bestRouter = address(0);
        bestRouterType = RouterType.V2;
        bestV3Fees = new uint24[](0);
        bestPriceImpact = type(uint).max;
        bestPath = path;

        // Check all V2 routers with direct and multi-hop paths
        for (uint i = 0; i < routersV2.length; i++) {
            if (!_validateRouter(routersV2[i])) continue;

            // Try direct path first - validate pair exists
            if (_validateV2Path(routersV2[i], path)) {
                (uint256 amountOut, uint256 impact) = _calculateV2SwapOutput(routersV2[i], path, amountIn);

                if (amountOut > 0 && amountOut > bestAmountOut) {
                    bestAmountOut = amountOut;
                    bestRouter = routersV2[i];
                    bestRouterType = RouterType.V2;
                    bestPriceImpact = impact;
                    bestPath = path;
                }
            }

            // For token-to-token swaps (not involving WETH), try routing through WETH
            if (path.length == 2 && path[0] != WETH && path[1] != WETH) {
                address[] memory wethPath = new address[](3);
                wethPath[0] = path[0];
                wethPath[1] = WETH;
                wethPath[2] = path[1];

                // Validate WETH path exists
                if (_validateV2Path(routersV2[i], wethPath)) {
                    (uint256 wethAmountOut, uint256 wethImpact) = _calculateV2SwapOutput(routersV2[i], wethPath, amountIn);

                    // If routing through WETH gives better price, use it
                    if (wethAmountOut > 0 && wethAmountOut > bestAmountOut) {
                        bestAmountOut = wethAmountOut;
                        bestRouter = routersV2[i];
                        bestRouterType = RouterType.V2;
                        bestPriceImpact = wethImpact;
                        bestPath = wethPath;
                    }
                }
            }
        }

        // Check all V3 routers (supports single and multi-hop)
        for (uint i = 0; i < routersV3.length; i++) {
            if (!_validateRouter(routersV3[i])) continue;

            address factory = v3RouterToFactory[routersV3[i]];
            if (factory == address(0)) continue;

            if (path.length == 2) {
                // Single-hop V3
                (address bestPool, uint24 bestFee, uint amountOut, uint impact) = _getBestV3Pool(
                    factory,
                    path[0],
                    path[1],
                    amountIn
                );

                if (bestPool != address(0) && amountOut > bestAmountOut) {
                    bestAmountOut = amountOut;
                    bestRouter = routersV3[i];
                    bestRouterType = RouterType.V3;
                    bestV3Fees = new uint24[](1);
                    bestV3Fees[0] = bestFee;
                    bestPriceImpact = impact;
                    bestPath = path;
                }
            }

            // Also try multi-hop through WETH for token-to-token
            if (path.length == 2 && path[0] != WETH && path[1] != WETH) {
                address[] memory wethPath = new address[](3);
                wethPath[0] = path[0];
                wethPath[1] = WETH;
                wethPath[2] = path[1];

                (address pool1, uint24 fee1, uint amountMid, uint impact1) = _getBestV3Pool(
                    factory,
                    wethPath[0],
                    wethPath[1],
                    amountIn
                );

                if (pool1 != address(0) && amountMid > 0) {
                    (address pool2, uint24 fee2, uint amountOut, uint impact2) = _getBestV3Pool(
                        factory,
                        wethPath[1],
                        wethPath[2],
                        amountMid
                    );

                    if (pool2 != address(0) && amountOut > bestAmountOut) {
                        bestAmountOut = amountOut;
                        bestRouter = routersV3[i];
                        bestRouterType = RouterType.V3;
                        bestV3Fees = new uint24[](2);
                        bestV3Fees[0] = fee1;
                        bestV3Fees[1] = fee2;
                        bestPriceImpact = impact1 + impact2;
                        bestPath = wethPath;
                    }
                }
            }
        }
    }

    /// @notice Calculate optimal split percentages across multiple ROUTERS (not fee tiers)
    /// @dev Uses greedy algorithm to find best distribution minimizing total impact
    /// @dev IMPORTANT: Splits only count different routers - fee tier variations within same router don't increase split count
    /// @dev ALWAYS attempts splitting when alwaysSplit is enabled, regardless of price impact
    function _calculateOptimalSplits(
        uint amountForSwap,
        address[] memory path,
        uint8 maxSplitsAllowed
    ) internal view returns (
        RouterQuote[] memory selectedQuotes,
        uint16[] memory percentages,
        uint totalExpectedOut
    ) {
        // Use _getBestQuotePerRouter to ensure splits count ROUTERS not fee tiers
        // Use smaller test amount for more quotes
        RouterQuote[] memory routerQuotes = _getBestQuotePerRouter(amountForSwap / 8, path);

        if (routerQuotes.length == 0) {
            return (new RouterQuote[](0), new uint16[](0), 0);
        }

        // Also get quotes using intermediate tokens to find more routes
        RouterQuote[] memory hopQuotes = _getAllRouterQuotesWithHops(amountForSwap / 8, path);

        // Merge and deduplicate quotes
        routerQuotes = _mergeRouterQuotes(routerQuotes, hopQuotes);

        // Sort quotes by amountOut descending
        routerQuotes = _sortQuotesByOutput(routerQuotes);

        // Determine optimal number of splits (2-4) based on unique routers
        // If alwaysSplit is enabled, force splitting even with single router by using fee tiers
        uint8 numSplits = maxSplitsAllowed > routerQuotes.length ? uint8(routerQuotes.length) : maxSplitsAllowed;
        if (numSplits > 4) numSplits = 4;

        // When alwaysSplit is true, try to get at least 2 splits
        if (numSplits < 2) {
            if (routerQuotes.length < 2) {
                // Even with 1 router, return it for single route fallback
                if (routerQuotes.length == 1 && !splitConfig.alwaysSplit) {
                    return (new RouterQuote[](0), new uint16[](0), 0);
                }
                // With alwaysSplit, use the single router with 100%
                if (routerQuotes.length == 1) {
                    selectedQuotes = new RouterQuote[](1);
                    percentages = new uint16[](1);
                    selectedQuotes[0] = routerQuotes[0];
                    percentages[0] = 10000;

                    // Recalculate output for full amount
                    if (routerQuotes[0].routerType == RouterType.V2) {
                        try IUniswapV2Router02(routerQuotes[0].router).getAmountsOut(amountForSwap, routerQuotes[0].path) returns (uint[] memory amounts) {
                            totalExpectedOut = amounts[amounts.length - 1];
                        } catch {}
                    } else {
                        address factory = v3RouterToFactory[routerQuotes[0].router];
                        if (factory != address(0) && routerQuotes[0].path.length == 2) {
                            address pool;
                            try IUniswapV3Factory(factory).getPool(routerQuotes[0].path[0], routerQuotes[0].path[1], routerQuotes[0].v3Fee) returns (address p) {
                                pool = p;
                            } catch {}
                            if (pool != address(0)) {
                                (uint256 out, ) = _calculateV3SwapOutput(pool, amountForSwap, routerQuotes[0].path[0], routerQuotes[0].v3Fee);
                                totalExpectedOut = out;
                            }
                        }
                    }
                    return (selectedQuotes, percentages, totalExpectedOut);
                }
                return (new RouterQuote[](0), new uint16[](0), 0);
            }
            numSplits = 2;
        }

        selectedQuotes = new RouterQuote[](numSplits);
        percentages = new uint16[](numSplits);

        // Copy top routers (each represents a unique router)
        for (uint i = 0; i < numSplits; i++) {
            selectedQuotes[i] = routerQuotes[i];
        }

        // Calculate optimal distribution using aggressive iterative refinement
        totalExpectedOut = _optimizeSplitPercentagesAggressive(selectedQuotes, percentages, amountForSwap, path);
    }

    /// @notice Get all router quotes including intermediate token hops
    /// @dev Explicitly tries all intermediate tokens to find pools that might be missed
    function _getAllRouterQuotesWithHops(uint amountIn, address[] memory path) internal view returns (RouterQuote[] memory) {
        if (path.length != 2) return new RouterQuote[](0);

        uint maxQuotes = (routersV2.length + routersV3.length) * intermediateTokens.length * 2;
        RouterQuote[] memory tempQuotes = new RouterQuote[](maxQuotes);
        uint quoteCount = 0;

        // For each intermediate token, try to find routes
        for (uint k = 0; k < intermediateTokens.length; k++) {
            address intermediate = intermediateTokens[k];
            if (intermediate == path[0] || intermediate == path[1]) continue;

            address[] memory hopPath = new address[](3);
            hopPath[0] = path[0];
            hopPath[1] = intermediate;
            hopPath[2] = path[1];

            // Check V2 routers with hop
            for (uint i = 0; i < routersV2.length; i++) {
                if (!_validateRouter(routersV2[i])) continue;

                if (_validateV2Path(routersV2[i], hopPath)) {
                    (uint256 amountOut, uint256 impact) = _calculateV2SwapOutput(routersV2[i], hopPath, amountIn);

                    if (amountOut > 0 && quoteCount < maxQuotes) {
                        tempQuotes[quoteCount] = RouterQuote({
                            router: routersV2[i],
                            routerType: RouterType.V2,
                            v3Fee: 0,
                            amountOut: amountOut,
                            priceImpact: impact,
                            path: hopPath
                        });
                        quoteCount++;
                    }
                }
            }

            // Check V3 routers with hop
            for (uint i = 0; i < routersV3.length; i++) {
                if (!_validateRouter(routersV3[i])) continue;

                address factory = v3RouterToFactory[routersV3[i]];
                if (factory == address(0)) continue;

                (address pool1, uint24 fee1, uint amountMid, uint impact1) = _getBestV3Pool(
                    factory, path[0], intermediate, amountIn
                );

                if (pool1 != address(0) && amountMid > 0) {
                    (address pool2, uint24 fee2, uint hopOut, uint impact2) = _getBestV3Pool(
                        factory, intermediate, path[1], amountMid
                    );

                    if (pool2 != address(0) && hopOut > 0 && quoteCount < maxQuotes) {
                        tempQuotes[quoteCount] = RouterQuote({
                            router: routersV3[i],
                            routerType: RouterType.V3,
                            v3Fee: fee1,
                            amountOut: hopOut,
                            priceImpact: impact1 + impact2,
                            path: hopPath
                        });
                        quoteCount++;
                    }
                }
            }
        }

        // Resize array
        RouterQuote[] memory result = new RouterQuote[](quoteCount);
        for (uint i = 0; i < quoteCount; i++) {
            result[i] = tempQuotes[i];
        }

        return result;
    }

    /// @notice Merge two arrays of router quotes, keeping best quote per router
    function _mergeRouterQuotes(RouterQuote[] memory quotes1, RouterQuote[] memory quotes2) internal pure returns (RouterQuote[] memory) {
        uint totalLen = quotes1.length + quotes2.length;
        if (totalLen == 0) return new RouterQuote[](0);

        RouterQuote[] memory merged = new RouterQuote[](totalLen);
        uint mergedCount = 0;

        // Add all from quotes1
        for (uint i = 0; i < quotes1.length; i++) {
            bool found = false;
            for (uint j = 0; j < mergedCount; j++) {
                if (merged[j].router == quotes1[i].router && 
                    keccak256(abi.encodePacked(merged[j].path)) == keccak256(abi.encodePacked(quotes1[i].path))) {
                    if (quotes1[i].amountOut > merged[j].amountOut) {
                        merged[j] = quotes1[i];
                    }
                    found = true;
                    break;
                }
            }
            if (!found) {
                merged[mergedCount] = quotes1[i];
                mergedCount++;
            }
        }

        // Add from quotes2, merging duplicates
        for (uint i = 0; i < quotes2.length; i++) {
            bool found = false;
            for (uint j = 0; j < mergedCount; j++) {
                if (merged[j].router == quotes2[i].router &&
                    keccak256(abi.encodePacked(merged[j].path)) == keccak256(abi.encodePacked(quotes2[i].path))) {
                    if (quotes2[i].amountOut > merged[j].amountOut) {
                        merged[j] = quotes2[i];
                    }
                    found = true;
                    break;
                }
            }
            if (!found && mergedCount < totalLen) {
                merged[mergedCount] = quotes2[i];
                mergedCount++;
            }
        }

        // Resize
        RouterQuote[] memory result = new RouterQuote[](mergedCount);
        for (uint i = 0; i < mergedCount; i++) {
            result[i] = merged[i];
        }

        return result;
    }

    /// @notice Sort quotes by output amount (descending)
    function _sortQuotesByOutput(RouterQuote[] memory quotes) internal pure returns (RouterQuote[] memory) {
        uint n = quotes.length;
        for (uint i = 0; i < n - 1; i++) {
            for (uint j = 0; j < n - i - 1; j++) {
                if (quotes[j].amountOut < quotes[j + 1].amountOut) {
                    RouterQuote memory temp = quotes[j];
                    quotes[j] = quotes[j + 1];
                    quotes[j + 1] = temp;
                }
            }
        }
        return quotes;
    }

    /// @notice Aggressive split percentage optimization to maximize output
    /// @dev Uses 10 iterations with larger step sizes for more aggressive optimization
    function _optimizeSplitPercentagesAggressive(
        RouterQuote[] memory quotes,
        uint16[] memory percentages,
        uint totalAmount,
        address[] memory path
    ) internal view returns (uint totalOut) {
        uint numSplits = quotes.length;
        if (numSplits == 0) return 0;

        // Start with proportional distribution based on initial quote quality
        uint totalQuoteOut = 0;
        for (uint i = 0; i < numSplits; i++) {
            totalQuoteOut += quotes[i].amountOut;
        }

        if (totalQuoteOut > 0) {
            uint16 remainingPct = 10000;
            for (uint i = 0; i < numSplits - 1; i++) {
                percentages[i] = uint16((quotes[i].amountOut * 10000) / totalQuoteOut);
                remainingPct -= percentages[i];
            }
            percentages[numSplits - 1] = remainingPct;
        } else {
            // Fallback to equal distribution
            uint16 equalShare = uint16(10000 / numSplits);
            for (uint i = 0; i < numSplits; i++) {
                percentages[i] = equalShare;
            }
            percentages[numSplits - 1] = uint16(10000 - uint16(equalShare) * uint16(numSplits - 1));
        }

        // Aggressive iterative optimization: 10 iterations with larger step sizes
        for (uint iteration = 0; iteration < 10; iteration++) {
            uint[] memory outputs = new uint[](numSplits);
            uint[] memory impacts = new uint[](numSplits);

            // Calculate output for each split with current allocation
            for (uint i = 0; i < numSplits; i++) {
                uint splitAmount = (totalAmount * percentages[i]) / 10000;
                if (splitAmount == 0) continue;

                if (quotes[i].routerType == RouterType.V2) {
                    (uint amtOut, uint impact) = _calculateV2SwapOutput(quotes[i].router, quotes[i].path, splitAmount);
                    outputs[i] = amtOut;
                    impacts[i] = impact;
                } else {
                    address factory = v3RouterToFactory[quotes[i].router];
                    if (factory == address(0)) continue;

                    // Handle multi-hop V3 paths
                    if (quotes[i].path.length == 2) {
                        address pool;
                        try IUniswapV3Factory(factory).getPool(quotes[i].path[0], quotes[i].path[1], quotes[i].v3Fee) returns (address p) {
                            pool = p;
                            if (pool != address(0)) {
                                (uint out, uint impact) = _calculateV3SwapOutput(pool, splitAmount, quotes[i].path[0], quotes[i].v3Fee);
                                outputs[i] = out;
                                impacts[i] = impact;
                            }
                        } catch {}
                    } else if (quotes[i].path.length == 3) {
                        // Multi-hop: get intermediate output then final
                        (address pool1, uint24 fee1, uint amountMid, uint impact1) = _getBestV3Pool(
                            factory, quotes[i].path[0], quotes[i].path[1], splitAmount
                        );
                        if (pool1 != address(0) && amountMid > 0) {
                            (address pool2, uint24 fee2, uint hopOut, uint impact2) = _getBestV3Pool(
                                factory, quotes[i].path[1], quotes[i].path[2], amountMid
                            );
                            if (pool2 != address(0)) {
                                outputs[i] = hopOut;
                                impacts[i] = impact1 + impact2;
                            }
                        }
                    }
                }
            }

            // Find router with best efficiency (output per percentage with impact consideration)
            uint bestRouter = 0;
            uint bestEfficiency = 0;
            for (uint i = 0; i < numSplits; i++) {
                if (percentages[i] >= 8000) continue; // Don't allocate more than 80% to one router
                if (outputs[i] == 0 || percentages[i] == 0) continue;

                // Efficiency score: output / percentage * (10000 - impact) / 10000
                uint efficiency = (outputs[i] * 10000) / percentages[i];
                efficiency = efficiency * (10000 - (impacts[i] > 10000 ? 10000 : impacts[i])) / 10000;

                if (efficiency > bestEfficiency) {
                    bestEfficiency = efficiency;
                    bestRouter = i;
                }
            }

            // Find worst performer
            uint worstRouter = 0;
            uint worstEfficiency = type(uint).max;
            for (uint i = 0; i < numSplits; i++) {
                if (i == bestRouter || percentages[i] <= 200) continue; // Keep at least 2%
                if (outputs[i] == 0) {
                    worstRouter = i;
                    worstEfficiency = 0;
                    break;
                }

                uint efficiency = (outputs[i] * 10000) / percentages[i];
                efficiency = efficiency * (10000 - (impacts[i] > 10000 ? 10000 : impacts[i])) / 10000;

                if (efficiency < worstEfficiency) {
                    worstEfficiency = efficiency;
                    worstRouter = i;
                }
            }

            // Aggressive shift: 10% per iteration (100 BPS)
            uint16 shiftAmount = 1000; // 10%
            if (iteration > 5) shiftAmount = 500; // Reduce to 5% for fine-tuning

            if (bestEfficiency > worstEfficiency && percentages[worstRouter] >= shiftAmount) {
                percentages[worstRouter] -= shiftAmount;
                percentages[bestRouter] += shiftAmount;
            }
        }

        // Calculate final expected output
        for (uint i = 0; i < numSplits; i++) {
            uint splitAmount = (totalAmount * percentages[i]) / 10000;
            if (splitAmount == 0) continue;

            if (quotes[i].routerType == RouterType.V2) {
                try IUniswapV2Router02(quotes[i].router).getAmountsOut(splitAmount, quotes[i].path) returns (uint[] memory amounts) {
                    totalOut += amounts[amounts.length - 1];
                } catch {}
            } else {
                address factory = v3RouterToFactory[quotes[i].router];
                if (factory == address(0)) continue;

                if (quotes[i].path.length == 2) {
                    address pool;
                    try IUniswapV3Factory(factory).getPool(quotes[i].path[0], quotes[i].path[1], quotes[i].v3Fee) returns (address p) {
                        pool = p;
                        if (pool != address(0)) {
                            (uint out, ) = _calculateV3SwapOutput(pool, splitAmount, quotes[i].path[0], quotes[i].v3Fee);
                            totalOut += out;
                        }
                    } catch {}
                } else if (quotes[i].path.length == 3) {
                    (address pool1, uint24 fee1, uint amountMid, ) = _getBestV3Pool(
                        factory, quotes[i].path[0], quotes[i].path[1], splitAmount
                    );
                    if (pool1 != address(0) && amountMid > 0) {
                        (address pool2, uint24 fee2, uint hopOut, ) = _getBestV3Pool(
                            factory, quotes[i].path[1], quotes[i].path[2], amountMid
                        );
                        if (pool2 != address(0)) {
                            totalOut += hopOut;
                        }
                    }
                }
            }
        }
    }

    /// @notice Calculate adaptive slippage based on price impact
    /// @dev For high impact (>1%), adds proportional slippage buffer
    /// @param amountOut Expected output amount
    /// @param priceImpact Price impact in basis points (100 = 1%)
    /// @param userSlippageBPS User-specified slippage, 0 for auto
    /// @return minAmountOut Minimum acceptable output amount
    function _calculateAdaptiveSlippage(
        uint256 amountOut,
        uint256 priceImpact,
        uint16 userSlippageBPS
    ) internal view returns (uint256 minAmountOut) {
        uint256 slippageBPS;

        if (userSlippageBPS > 0) {
            // User override
            require(userSlippageBPS <= slippageConfig.maxSlippageBPS, "MonBridgeDex: Slippage too high");
            slippageBPS = userSlippageBPS;
        } else {
            // Adaptive calculation
            slippageBPS = slippageConfig.baseSlippageBPS; // Start with base (e.g., 50 = 0.5%)

            // Add buffer for high impact trades
            if (priceImpact > 100) { // > 1% impact
                uint256 additionalSlippage = (priceImpact * slippageConfig.impactMultiplier) / 10000;
                slippageBPS += additionalSlippage;
            }

            // Cap at maximum allowed
            if (slippageBPS > slippageConfig.maxSlippageBPS) {
                slippageBPS = slippageConfig.maxSlippageBPS;
            }
        }

        // Calculate minimum output: amountOut * (1 - slippage%)
        minAmountOut = (amountOut * (10000 - slippageBPS)) / 10000;
    }

    /// @notice Get the best swap data with adaptive slippage, optimal routing, and automatic split detection
    /// @dev GUARANTEED to return valid swap data - tries V2 and V3, returns best available
    /// @dev Automatically suggests splitting if price impact exceeds threshold (use getBestSwapDataWithSplits for split data)
    function getBestSwapData(
        uint amountIn,
        address[] calldata path,
        bool supportFeeOnTransfer,
        uint16 userSlippageBPS
    )
        external
        view
        returns (SwapData memory swapData)
    {
        require(path.length >= 2, "MonBridgeDex: Invalid path, must have at least 2 tokens");
        require(amountIn > 0, "MonBridgeDex: Amount must be greater than 0");

        uint fee = amountIn / FEE_DIVISOR;
        uint amountForSwap = amountIn - fee;

        // Find best route (may include WETH routing for V2 or V3)
        // This function internally tries BOTH V2 and V3, and returns the best one
        // If one fails, it automatically falls back to the other
        (address bestRouter, uint bestAmountOut, RouterType routerType, uint24[] memory v3Fees, uint priceImpact, address[] memory optimalPath) =
            _getBestRouterWithPath(amountForSwap, path);

        // _getBestRouterWithPath now has a require() that ensures bestRouter != address(0)
        // So if we reach here, we ALWAYS have a valid router (either V2 or V3)
        require(bestRouter != address(0), "MonBridgeDex: No valid router found for this swap path");
        require(bestAmountOut > 0, "MonBridgeDex: No valid quote available");

        // Determine swap type based on optimal path
        SwapType swapType;
        if (optimalPath[0] == WETH) {
            swapType = SwapType.ETH_TO_TOKEN;
        } else if (optimalPath[optimalPath.length - 1] == WETH) {
            swapType = SwapType.TOKEN_TO_ETH;
        } else {
            // Multi-hop through WETH or direct token-to-token
            swapType = SwapType.TOKEN_TO_TOKEN;
        }

        uint amountOutMin = _calculateAdaptiveSlippage(bestAmountOut, priceImpact, userSlippageBPS);

        // Use fees returned from _getBestRouterWithPath, or create default array for V2
        if (routerType == RouterType.V2 || v3Fees.length == 0) {
            v3Fees = new uint24[](1);
            v3Fees[0] = 0;
        }

        swapData = SwapData({
            swapType: swapType,
            routerType: routerType,
            router: bestRouter,
            path: optimalPath, // Use optimal path (may be multi-hop)
            v3Fees: v3Fees,
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            deadline: block.timestamp + 300,
            supportFeeOnTransfer: supportFeeOnTransfer
        });
    }

    /// @notice Get split swap data with automatic distribution across 2-4 routers
    function getSplitSwapData(
        uint amountIn,
        address[] calldata path,
        bool supportFeeOnTransfer,
        uint16 userSlippageBPS
    )
        external
        view
        returns (SplitSwapData memory splitData)
    {
        require(path.length >= 2, "MonBridgeDex: Invalid path, must have at least 2 tokens");
        require(amountIn > 0, "MonBridgeDex: Amount must be greater than 0");
        require(splitConfig.enableAutoSplit, "MonBridgeDex: Auto-split disabled");

        uint fee = amountIn / FEE_DIVISOR;
        uint amountForSwap = amountIn - fee;

        // Calculate optimal splits
        (RouterQuote[] memory quotes, uint16[] memory percentages, uint totalExpectedOut) =
            _calculateOptimalSplits(amountForSwap, path, splitConfig.maxSplits);

        require(quotes.length >= 2, "MonBridgeDex: Insufficient routers for split");

        // Build individual swap data for each split
        SwapData[] memory splits = new SwapData[](quotes.length);

        for (uint i = 0; i < quotes.length; i++) {
            // Use GROSS amount for execution - execute() will deduct fees
            // The quote comparison uses post-fee, but execution needs gross
            uint splitAmountGross = (amountIn * percentages[i]) / 10000;

            // Determine swap type
            SwapType swapType;
            if (quotes[i].path[0] == WETH) {
                swapType = SwapType.ETH_TO_TOKEN;
            } else if (quotes[i].path[quotes[i].path.length - 1] == WETH) {
                swapType = SwapType.TOKEN_TO_ETH;
            } else {
                swapType = SwapType.TOKEN_TO_TOKEN;
            }

            // Create proper fee array for V3 multi-hop
            uint24[] memory v3Fees;
            if (quotes[i].routerType == RouterType.V3 && quotes[i].path.length > 2) {
                v3Fees = new uint24[](quotes[i].path.length - 1);
                for (uint j = 0; j < v3Fees.length; j++) {
                    v3Fees[j] = quotes[i].v3Fee; // Use same fee tier for all hops
                }
            } else {
                v3Fees = new uint24[](1);
                v3Fees[0] = quotes[i].v3Fee;
            }

            uint splitExpectedOut = (quotes[i].amountOut * percentages[i]) / 10000;
            uint splitMinOut = _calculateAdaptiveSlippage(splitExpectedOut, quotes[i].priceImpact, userSlippageBPS);

            splits[i] = SwapData({
                swapType: swapType,
                routerType: quotes[i].routerType,
                router: quotes[i].router,
                path: quotes[i].path,
                v3Fees: v3Fees,
                amountIn: splitAmountGross, // Gross amount - execute() deducts fees
                amountOutMin: splitMinOut,
                deadline: block.timestamp + 300,
                supportFeeOnTransfer: supportFeeOnTransfer
            });
        }

        uint totalMinOut = _calculateAdaptiveSlippage(totalExpectedOut, 0, userSlippageBPS);

        splitData = SplitSwapData({
            splits: splits,
            totalAmountIn: amountIn, // Gross total for execution
            totalAmountOutMin: totalMinOut,
            splitPercentages: percentages
        });
    }

    /// @notice Comprehensive swap data function that automatically handles single, multi-hop, and split strategies
    /// @dev This is the recommended entry point - automatically chooses optimal strategy based on price impact
    /// @param amountIn Input amount
    /// @param path Token path for the swap
    /// @param supportFeeOnTransfer Whether to support fee-on-transfer tokens
    /// @param userSlippageBPS User-specified slippage (0 for auto)
    /// @return useSplit Whether split swap is recommended (true) or single swap (false)
    /// @return singleSwapData Single swap data (valid if useSplit is false)
    /// @return splitSwapData Split swap data (valid if useSplit is true)
    /// @return estimatedOutput Best estimated output amount
    /// @return totalPriceImpact Combined price impact in basis points
    function getBestSwapDataWithSplits(
        uint amountIn,
        address[] calldata path,
        bool supportFeeOnTransfer,
        uint16 userSlippageBPS
    )
        external
        view
        returns (
            bool useSplit,
            SwapData memory singleSwapData,
            SplitSwapData memory splitSwapData,
            uint estimatedOutput,
            uint totalPriceImpact
        )
    {
        require(path.length >= 2, "MonBridgeDex: Invalid path");
        require(amountIn > 0, "MonBridgeDex: Amount must be > 0");

        uint fee = amountIn / FEE_DIVISOR;
        uint amountForSwap = amountIn - fee;

        // Step 1: Get best single route with price impact
        (address bestRouter, uint singleOutput, RouterType routerType, uint24[] memory v3Fees, uint singleImpact, address[] memory optimalPath) =
            _getBestRouterWithPath(amountForSwap, path);

        // Step 2: Check if splitting would give better results (if enabled)
        // When alwaysSplit is enabled, ALWAYS try splitting regardless of current impact
        uint splitOutput = 0;
        uint splitImpact = type(uint).max;
        bool splitAvailable = false;

        // Always try splitting if alwaysSplit is enabled OR if impact exceeds threshold
        bool shouldTrySplit = splitConfig.enableAutoSplit && 
            (splitConfig.alwaysSplit || singleImpact >= splitConfig.minSplitImpactBPS);

        if (shouldTrySplit) {
            // Try to calculate split strategy
            (RouterQuote[] memory quotes, uint16[] memory percentages, uint totalExpectedOut) =
                _calculateOptimalSplits(amountForSwap, path, splitConfig.maxSplits);

            // Accept splits even with single router when alwaysSplit is enabled
            if ((quotes.length >= 2 || (quotes.length >= 1 && splitConfig.alwaysSplit)) && totalExpectedOut > 0) {
                splitOutput = totalExpectedOut;
                splitAvailable = true;

                // Calculate weighted average price impact for splits
                uint weightedImpact = 0;
                for (uint i = 0; i < quotes.length; i++) {
                    weightedImpact += quotes[i].priceImpact * percentages[i];
                }
                splitImpact = weightedImpact / 10000;
            }
        }

        // Step 3: Decide whether to use single or split
        // IMPORTANT: Always consider fees - only split if output is equal or better
        // Split routes have pool fees baked into amountOut, so we compare total outputs
        // Use split if: split is available AND split output >= single output (accounting for all pool fees)
        if (splitConfig.alwaysSplit) {
            // With alwaysSplit: use split if output is at least equal (fees are already in amountOut)
            // This ensures we never lose money by splitting - pool fees are accounted for in quotes
            useSplit = splitAvailable && splitOutput > 0 && splitOutput >= singleOutput;
        } else {
            // Without alwaysSplit: only split if meaningfully better output or lower impact
            useSplit = splitAvailable && (splitOutput > singleOutput || (splitOutput >= singleOutput * 99 / 100 && splitImpact < singleImpact));
        }

        if (useSplit) {
            // Build split swap data
            (RouterQuote[] memory quotes, uint16[] memory percentages, ) =
                _calculateOptimalSplits(amountForSwap, path, splitConfig.maxSplits);

            SwapData[] memory splits = new SwapData[](quotes.length);
            for (uint i = 0; i < quotes.length; i++) {
                // Use GROSS amount for execution - execute() will deduct fees
                // The quote comparison uses post-fee, but execution needs gross
                uint splitAmountGross = (amountIn * percentages[i]) / 10000;

                SwapType swapType;
                if (quotes[i].path[0] == WETH) {
                    swapType = SwapType.ETH_TO_TOKEN;
                } else if (quotes[i].path[quotes[i].path.length - 1] == WETH) {
                    swapType = SwapType.TOKEN_TO_ETH;
                } else {
                    swapType = SwapType.TOKEN_TO_TOKEN;
                }

                uint24[] memory splitV3Fees;
                if (quotes[i].routerType == RouterType.V3 && quotes[i].path.length > 2) {
                    splitV3Fees = new uint24[](quotes[i].path.length - 1);
                    for (uint j = 0; j < splitV3Fees.length; j++) {
                        splitV3Fees[j] = quotes[i].v3Fee;
                    }
                } else {
                    splitV3Fees = new uint24[](1);
                    splitV3Fees[0] = quotes[i].v3Fee;
                }

                uint splitExpectedOut = (quotes[i].amountOut * percentages[i]) / 10000;
                uint splitMinOut = _calculateAdaptiveSlippage(splitExpectedOut, quotes[i].priceImpact, userSlippageBPS);

                splits[i] = SwapData({
                    swapType: swapType,
                    routerType: quotes[i].routerType,
                    router: quotes[i].router,
                    path: quotes[i].path,
                    v3Fees: splitV3Fees,
                    amountIn: splitAmountGross, // Gross amount - execute() deducts fees
                    amountOutMin: splitMinOut,
                    deadline: block.timestamp + 300,
                    supportFeeOnTransfer: supportFeeOnTransfer
                });
            }

            uint totalMinOut = _calculateAdaptiveSlippage(splitOutput, splitImpact, userSlippageBPS);
            splitSwapData = SplitSwapData({
                splits: splits,
                totalAmountIn: amountIn, // Gross total for execution
                totalAmountOutMin: totalMinOut,
                splitPercentages: percentages
            });

            estimatedOutput = splitOutput;
            totalPriceImpact = splitImpact;
        } else {
            // Build single swap data
            require(bestRouter != address(0), "MonBridgeDex: No valid route found");

            SwapType swapType;
            if (optimalPath[0] == WETH) {
                swapType = SwapType.ETH_TO_TOKEN;
            } else if (optimalPath[optimalPath.length - 1] == WETH) {
                swapType = SwapType.TOKEN_TO_ETH;
            } else {
                swapType = SwapType.TOKEN_TO_TOKEN;
            }

            if (routerType == RouterType.V2 || v3Fees.length == 0) {
                v3Fees = new uint24[](1);
                v3Fees[0] = 0;
            }

            uint amountOutMin = _calculateAdaptiveSlippage(singleOutput, singleImpact, userSlippageBPS);

            singleSwapData = SwapData({
                swapType: swapType,
                routerType: routerType,
                router: bestRouter,
                path: optimalPath,
                v3Fees: v3Fees,
                amountIn: amountIn,
                amountOutMin: amountOutMin,
                deadline: block.timestamp + 300,
                supportFeeOnTransfer: supportFeeOnTransfer
            });

            estimatedOutput = singleOutput;
            totalPriceImpact = singleImpact;
        }
    }

    /// @notice Get quotes from all available routers using all intermediate tokens
    /// @dev Returns individual quotes for splitting - each router+path combo is a quote
    function _getAllRouterQuotes(uint amountIn, address[] memory path) internal view returns (RouterQuote[] memory) {
        // Account for all intermediate tokens and multiple fee tiers
        uint maxQuotes = routersV2.length * (1 + intermediateTokens.length) + 
                         routersV3.length * v3FeeTiers.length * (1 + intermediateTokens.length);
        RouterQuote[] memory tempQuotes = new RouterQuote[](maxQuotes);
        uint quoteCount = 0;

        // Get V2 quotes with all paths
        for (uint i = 0; i < routersV2.length; i++) {
            if (!_validateRouter(routersV2[i])) continue;

            // Try direct path
            if (_validateV2Path(routersV2[i], path)) {
                (uint256 amountOut, uint256 impact) = _calculateV2SwapOutput(routersV2[i], path, amountIn);

                if (amountOut > 0 && quoteCount < maxQuotes) {
                    tempQuotes[quoteCount] = RouterQuote({
                        router: routersV2[i],
                        routerType: RouterType.V2,
                        v3Fee: 0,
                        amountOut: amountOut,
                        priceImpact: impact,
                        path: path
                    });
                    quoteCount++;
                }
            }

            // Try all intermediate token paths
            if (path.length == 2) {
                for (uint k = 0; k < intermediateTokens.length; k++) {
                    address intermediate = intermediateTokens[k];
                    if (intermediate == path[0] || intermediate == path[1]) continue;

                    address[] memory hopPath = new address[](3);
                    hopPath[0] = path[0];
                    hopPath[1] = intermediate;
                    hopPath[2] = path[1];

                    if (_validateV2Path(routersV2[i], hopPath)) {
                        (uint256 hopOut, uint256 hopImpact) = _calculateV2SwapOutput(routersV2[i], hopPath, amountIn);

                        if (hopOut > 0 && quoteCount < maxQuotes) {
                            tempQuotes[quoteCount] = RouterQuote({
                                router: routersV2[i],
                                routerType: RouterType.V2,
                                v3Fee: 0,
                                amountOut: hopOut,
                                priceImpact: hopImpact,
                                path: hopPath
                            });
                            quoteCount++;
                        }
                    }
                }
            }
        }

        // Get V3 quotes with all fee tiers and paths
        if (path.length == 2) {
            for (uint i = 0; i < routersV3.length; i++) {
                if (!_validateRouter(routersV3[i])) continue;

                address factory = v3RouterToFactory[routersV3[i]];
                if (factory == address(0)) continue;

                // Direct path with all fee tiers
                for (uint j = 0; j < v3FeeTiers.length; j++) {
                    uint24 fee = v3FeeTiers[j];

                    if (!_v3PoolExists(factory, path[0], path[1], fee)) continue;

                    address pool;
                    try IUniswapV3Factory(factory).getPool(path[0], path[1], fee) returns (address p) {
                        pool = p;
                    } catch {
                        continue;
                    }

                    if (pool == address(0)) continue;

                    (uint amountOut, uint impact) = _calculateV3SwapOutput(pool, amountIn, path[0], fee);

                    if (amountOut > 0 && quoteCount < maxQuotes) {
                        tempQuotes[quoteCount] = RouterQuote({
                            router: routersV3[i],
                            routerType: RouterType.V3,
                            v3Fee: fee,
                            amountOut: amountOut,
                            priceImpact: impact,
                            path: path
                        });
                        quoteCount++;
                    }
                }

                // Multi-hop through all intermediate tokens
                for (uint k = 0; k < intermediateTokens.length; k++) {
                    address intermediate = intermediateTokens[k];
                    if (intermediate == path[0] || intermediate == path[1]) continue;

                    // Find best fee tier combo for this hop path
                    (address pool1, uint24 fee1, uint amountMid, uint impact1) = _getBestV3Pool(
                        factory, path[0], intermediate, amountIn
                    );

                    if (pool1 != address(0) && amountMid > 0) {
                        (address pool2, uint24 fee2, uint hopOut, uint impact2) = _getBestV3Pool(
                            factory, intermediate, path[1], amountMid
                        );

                        if (pool2 != address(0) && hopOut > 0 && quoteCount < maxQuotes) {
                            address[] memory hopPath = new address[](3);
                            hopPath[0] = path[0];
                            hopPath[1] = intermediate;
                            hopPath[2] = path[1];

                            tempQuotes[quoteCount] = RouterQuote({
                                router: routersV3[i],
                                routerType: RouterType.V3,
                                v3Fee: fee1, // Store first hop fee, second is computed
                                amountOut: hopOut,
                                priceImpact: impact1 + impact2,
                                path: hopPath
                            });
                            quoteCount++;
                        }
                    }
                }
            }
        }

        // Resize array to actual count
        RouterQuote[] memory quotes = new RouterQuote[](quoteCount);
        for (uint i = 0; i < quoteCount; i++) {
            quotes[i] = tempQuotes[i];
        }

        return quotes;
    }

    /// @notice Get BEST quote per router (not per fee tier) for proper split counting
    /// @dev This ensures splits only count different routers, not different fee tiers
    function _getBestQuotePerRouter(uint amountIn, address[] memory path) internal view returns (RouterQuote[] memory) {
        RouterQuote[] memory allQuotes = _getAllRouterQuotes(amountIn, path);

        // Find unique routers and keep best quote for each
        uint uniqueCount = 0;
        address[] memory seenRouters = new address[](routersV2.length + routersV3.length);
        RouterQuote[] memory bestPerRouter = new RouterQuote[](routersV2.length + routersV3.length);

        for (uint i = 0; i < allQuotes.length; i++) {
            bool found = false;
            uint routerIdx = 0;

            for (uint j = 0; j < uniqueCount; j++) {
                if (seenRouters[j] == allQuotes[i].router) {
                    found = true;
                    routerIdx = j;
                    break;
                }
            }

            if (!found) {
                seenRouters[uniqueCount] = allQuotes[i].router;
                bestPerRouter[uniqueCount] = allQuotes[i];
                uniqueCount++;
            } else if (allQuotes[i].amountOut > bestPerRouter[routerIdx].amountOut) {
                // Update with better quote for same router
                bestPerRouter[routerIdx] = allQuotes[i];
            }
        }

        // Resize to actual count
        RouterQuote[] memory result = new RouterQuote[](uniqueCount);
        for (uint i = 0; i < uniqueCount; i++) {
            result[i] = bestPerRouter[i];
        }

        return result;
    }

    // ============ INTRA-ROUTER FEE TIER DISTRIBUTION ============

    /// @notice Get all available fee tier quotes for a single V3 router
    /// @dev Returns quotes for all fee tiers that have valid pools with liquidity
    function _getAllFeeTierQuotes(
        address router,
        address factory,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (FeeTierQuote[] memory) {
        FeeTierQuote[] memory tempQuotes = new FeeTierQuote[](v3FeeTiers.length);
        uint256 quoteCount = 0;

        for (uint i = 0; i < v3FeeTiers.length; i++) {
            uint24 fee = v3FeeTiers[i];

            if (!_v3PoolExists(factory, tokenIn, tokenOut, fee)) continue;

            address pool;
            try IUniswapV3Factory(factory).getPool(tokenIn, tokenOut, fee) returns (address p) {
                pool = p;
            } catch {
                continue;
            }

            if (pool == address(0)) continue;

            uint128 liquidity;
            try IUniswapV3Pool(pool).liquidity() returns (uint128 liq) {
                liquidity = liq;
            } catch {
                continue;
            }

            (uint256 amountOut, uint256 impact) = _calculateV3SwapOutput(pool, amountIn, tokenIn, fee);

            if (amountOut > 0 && impact < type(uint256).max) {
                address[] memory path = new address[](2);
                path[0] = tokenIn;
                path[1] = tokenOut;

                tempQuotes[quoteCount] = FeeTierQuote({
                    feeTier: fee,
                    path: path,
                    amountOut: amountOut,
                    priceImpact: impact,
                    liquidity: uint256(liquidity)
                });
                quoteCount++;
            }
        }

        // Also check intermediate token paths for each fee tier
        for (uint k = 0; k < intermediateTokens.length; k++) {
            address intermediate = intermediateTokens[k];
            if (intermediate == tokenIn || intermediate == tokenOut) continue;

            for (uint i = 0; i < v3FeeTiers.length; i++) {
                uint24 fee1 = v3FeeTiers[i];

                (address pool1, uint24 bestFee1, uint256 amountMid, uint256 impact1) = _getBestV3Pool(
                    factory, tokenIn, intermediate, amountIn
                );

                if (pool1 == address(0) || amountMid == 0) continue;

                (address pool2, uint24 bestFee2, uint256 hopOut, uint256 impact2) = _getBestV3Pool(
                    factory, intermediate, tokenOut, amountMid
                );

                if (pool2 != address(0) && hopOut > 0 && quoteCount < v3FeeTiers.length * 4) {
                    address[] memory hopPath = new address[](3);
                    hopPath[0] = tokenIn;
                    hopPath[1] = intermediate;
                    hopPath[2] = tokenOut;

                    uint128 liq1;
                    uint128 liq2;
                    try IUniswapV3Pool(pool1).liquidity() returns (uint128 l) { liq1 = l; } catch {}
                    try IUniswapV3Pool(pool2).liquidity() returns (uint128 l) { liq2 = l; } catch {}

                    tempQuotes[quoteCount] = FeeTierQuote({
                        feeTier: bestFee1, // Store first hop fee
                        path: hopPath,
                        amountOut: hopOut,
                        priceImpact: impact1 + impact2,
                        liquidity: uint256(liq1 < liq2 ? liq1 : liq2) // Use minimum liquidity
                    });
                    quoteCount++;
                }
                break; // Only need one hop path per intermediate
            }
        }

        // Resize array
        FeeTierQuote[] memory result = new FeeTierQuote[](quoteCount);
        for (uint i = 0; i < quoteCount; i++) {
            result[i] = tempQuotes[i];
        }

        return result;
    }

    /// @notice Calculate optimal intra-router split across fee tiers
    /// @dev Distributes a trade within a single V3 router across multiple fee tiers for lower impact
    function _calculateIntraRouterSplit(
        address router,
        address factory,
        address tokenIn,
        address tokenOut,
        uint256 totalAmount
    ) internal view returns (
        FeeTierQuote[] memory selectedQuotes,
        uint16[] memory percentages,
        uint256 totalExpectedOut
    ) {
        // Get all available fee tier quotes
        FeeTierQuote[] memory allQuotes = _getAllFeeTierQuotes(router, factory, tokenIn, tokenOut, totalAmount / 4);

        if (allQuotes.length == 0) {
            return (new FeeTierQuote[](0), new uint16[](0), 0);
        }

        if (allQuotes.length == 1) {
            // Only one tier available, use 100%
            selectedQuotes = new FeeTierQuote[](1);
            percentages = new uint16[](1);
            selectedQuotes[0] = allQuotes[0];
            percentages[0] = 10000;

            // Recalculate with full amount
            address pool;
            try IUniswapV3Factory(factory).getPool(tokenIn, tokenOut, allQuotes[0].feeTier) returns (address p) {
                pool = p;
            } catch {}

            if (pool != address(0)) {
                (uint256 out, ) = _calculateV3SwapOutput(pool, totalAmount, tokenIn, allQuotes[0].feeTier);
                totalExpectedOut = out;
            }
            return (selectedQuotes, percentages, totalExpectedOut);
        }

        // Sort by liquidity (highest first) to prioritize deep pools
        allQuotes = _sortFeeTierQuotesByLiquidity(allQuotes);

        // Use up to 4 fee tiers
        uint8 numTiers = uint8(allQuotes.length > 4 ? 4 : allQuotes.length);
        selectedQuotes = new FeeTierQuote[](numTiers);
        percentages = new uint16[](numTiers);

        // Copy top tiers
        for (uint i = 0; i < numTiers; i++) {
            selectedQuotes[i] = allQuotes[i];
        }

        // Calculate initial distribution based on liquidity
        uint256 totalLiquidity = 0;
        for (uint i = 0; i < numTiers; i++) {
            totalLiquidity += selectedQuotes[i].liquidity;
        }

        if (totalLiquidity > 0) {
            uint16 remainingPct = 10000;
            for (uint i = 0; i < numTiers - 1; i++) {
                // Scale down large liquidity values to prevent overflow
                uint256 scaledLiq = selectedQuotes[i].liquidity;
                uint256 scaledTotal = totalLiquidity;

                // Scale down if values are too large
                while (scaledLiq > type(uint128).max || scaledTotal > type(uint128).max) {
                    scaledLiq = scaledLiq / 1e6;
                    scaledTotal = scaledTotal / 1e6;
                }

                if (scaledTotal > 0) {
                    percentages[i] = uint16((scaledLiq * 10000) / scaledTotal);
                } else {
                    percentages[i] = uint16(10000 / numTiers);
                }
                remainingPct -= percentages[i];
            }
            percentages[numTiers - 1] = remainingPct;
        } else {
            // Equal distribution fallback
            uint16 equalShare = uint16(10000 / numTiers);
            for (uint i = 0; i < numTiers; i++) {
                percentages[i] = equalShare;
            }
            percentages[numTiers - 1] = uint16(10000 - equalShare * (numTiers - 1));
        }

        // Optimize distribution through iterations
        totalExpectedOut = _optimizeIntraRouterSplit(router, factory, tokenIn, tokenOut, totalAmount, selectedQuotes, percentages);
    }

    /// @notice Sort fee tier quotes by liquidity (descending)
    function _sortFeeTierQuotesByLiquidity(FeeTierQuote[] memory quotes) internal pure returns (FeeTierQuote[] memory) {
        uint n = quotes.length;
        for (uint i = 0; i < n - 1; i++) {
            for (uint j = 0; j < n - i - 1; j++) {
                if (quotes[j].liquidity < quotes[j + 1].liquidity) {
                    FeeTierQuote memory temp = quotes[j];
                    quotes[j] = quotes[j + 1];
                    quotes[j + 1] = temp;
                }
            }
        }
        return quotes;
    }

    /// @notice Iteratively optimize intra-router split percentages
    function _optimizeIntraRouterSplit(
        address router,
        address factory,
        address tokenIn,
        address tokenOut,
        uint256 totalAmount,
        FeeTierQuote[] memory quotes,
        uint16[] memory percentages
    ) internal view returns (uint256 totalOut) {
        uint numTiers = quotes.length;
        if (numTiers == 0) return 0;

        // 5 iterations of optimization
        for (uint iteration = 0; iteration < 5; iteration++) {
            uint256[] memory outputs = new uint256[](numTiers);
            uint256[] memory impacts = new uint256[](numTiers);

            // Calculate output for each tier with current allocation
            for (uint i = 0; i < numTiers; i++) {
                uint256 splitAmount = (totalAmount * percentages[i]) / 10000;
                if (splitAmount == 0) continue;

                if (quotes[i].path.length == 2) {
                    address pool;
                    try IUniswapV3Factory(factory).getPool(quotes[i].path[0], quotes[i].path[1], quotes[i].feeTier) returns (address p) {
                        pool = p;
                    } catch {}

                    if (pool != address(0)) {
                        (uint256 out, uint256 impact) = _calculateV3SwapOutput(pool, splitAmount, tokenIn, quotes[i].feeTier);
                        outputs[i] = out;
                        impacts[i] = impact;
                    }
                } else if (quotes[i].path.length == 3) {
                    // Multi-hop path
                    (address pool1, uint24 fee1, uint256 amountMid, uint256 impact1) = _getBestV3Pool(
                        factory, quotes[i].path[0], quotes[i].path[1], splitAmount
                    );
                    if (pool1 != address(0) && amountMid > 0) {
                        (address pool2, uint24 fee2, uint256 hopOut, uint256 impact2) = _getBestV3Pool(
                            factory, quotes[i].path[1], quotes[i].path[2], amountMid
                        );
                        if (pool2 != address(0)) {
                            outputs[i] = hopOut;
                            impacts[i] = impact1 + impact2;
                        }
                    }
                }
            }

            // Find best and worst performers
            uint bestTier = 0;
            uint256 bestEfficiency = 0;
            for (uint i = 0; i < numTiers; i++) {
                if (percentages[i] >= 7000) continue; // Max 70% per tier
                if (outputs[i] == 0 || percentages[i] == 0) continue;

                uint256 efficiency = (outputs[i] * 10000) / percentages[i];
                efficiency = efficiency * (10000 - (impacts[i] > 10000 ? 10000 : impacts[i])) / 10000;

                if (efficiency > bestEfficiency) {
                    bestEfficiency = efficiency;
                    bestTier = i;
                }
            }

            uint worstTier = 0;
            uint256 worstEfficiency = type(uint256).max;
            for (uint i = 0; i < numTiers; i++) {
                if (i == bestTier || percentages[i] <= 500) continue; // Keep at least 5%
                if (outputs[i] == 0) {
                    worstTier = i;
                    worstEfficiency = 0;
                    break;
                }

                uint256 efficiency = (outputs[i] * 10000) / percentages[i];
                efficiency = efficiency * (10000 - (impacts[i] > 10000 ? 10000 : impacts[i])) / 10000;

                if (efficiency < worstEfficiency) {
                    worstEfficiency = efficiency;
                    worstTier = i;
                }
            }

            // Shift allocation
            uint16 shiftAmount = 500; // 5% per iteration
            if (bestEfficiency > worstEfficiency && percentages[worstTier] >= shiftAmount) {
                percentages[worstTier] -= shiftAmount;
                percentages[bestTier] += shiftAmount;
            }
        }

        // Calculate final output
        for (uint i = 0; i < numTiers; i++) {
            uint256 splitAmount = (totalAmount * percentages[i]) / 10000;
            if (splitAmount == 0) continue;

            if (quotes[i].path.length == 2) {
                address pool;
                try IUniswapV3Factory(factory).getPool(quotes[i].path[0], quotes[i].path[1], quotes[i].feeTier) returns (address p) {
                    pool = p;
                } catch {}

                if (pool != address(0)) {
                    (uint256 out, ) = _calculateV3SwapOutput(pool, splitAmount, tokenIn, quotes[i].feeTier);
                    totalOut += out;
                }
            } else if (quotes[i].path.length == 3) {
                (address pool1, , uint256 amountMid, ) = _getBestV3Pool(
                    factory, quotes[i].path[0], quotes[i].path[1], splitAmount
                );
                if (pool1 != address(0) && amountMid > 0) {
                    (address pool2, , uint256 hopOut, ) = _getBestV3Pool(
                        factory, quotes[i].path[1], quotes[i].path[2], amountMid
                    );
                    if (pool2 != address(0)) {
                        totalOut += hopOut;
                    }
                }
            }
        }
    }

    /// @notice Get enhanced split data with intra-router fee tier distribution
    /// @dev Returns both cross-router splits AND within-router fee tier splits
    function getEnhancedSplitSwapData(
        uint amountIn,
        address[] calldata path,
        bool supportFeeOnTransfer,
        uint16 userSlippageBPS
    ) external view returns (
        RouterStrategy[] memory strategies,
        uint256 totalExpectedOutput,
        uint256 weightedPriceImpact
    ) {
        require(path.length >= 2, "MonBridgeDex: Invalid path");
        require(amountIn > 0, "MonBridgeDex: Amount must be > 0");

        uint fee = amountIn / FEE_DIVISOR;
        uint amountForSwap = amountIn - fee;

        // Get best quotes per router first
        RouterQuote[] memory routerQuotes = _getBestQuotePerRouter(amountForSwap / 4, path);

        if (routerQuotes.length == 0) {
            return (new RouterStrategy[](0), 0, type(uint256).max);
        }

        // Sort by output
        routerQuotes = _sortQuotesByOutput(routerQuotes);

        // Determine number of routers to use
        uint8 numRouters = routerQuotes.length > splitConfig.maxSplits ? splitConfig.maxSplits : uint8(routerQuotes.length);

        strategies = new RouterStrategy[](numRouters);

        // Calculate cross-router allocation first
        uint16[] memory routerPercentages = new uint16[](numRouters);
        uint256 totalQuoteOut = 0;
        for (uint i = 0; i < numRouters; i++) {
            totalQuoteOut += routerQuotes[i].amountOut;
        }

        if (totalQuoteOut > 0) {
            uint16 remainingPct = 10000;
            for (uint i = 0; i < numRouters - 1; i++) {
                routerPercentages[i] = uint16((routerQuotes[i].amountOut * 10000) / totalQuoteOut);
                remainingPct -= routerPercentages[i];
            }
            routerPercentages[numRouters - 1] = remainingPct;
        } else {
            uint16 equalShare = uint16(10000 / numRouters);
            for (uint i = 0; i < numRouters; i++) {
                routerPercentages[i] = equalShare;
            }
        }

        // For each router, calculate intra-router fee tier distribution
        for (uint i = 0; i < numRouters; i++) {
            uint256 routerAmount = (amountForSwap * routerPercentages[i]) / 10000;

            strategies[i].router = routerQuotes[i].router;
            strategies[i].routerType = routerQuotes[i].routerType;
            strategies[i].allocationBPS = routerPercentages[i];

            if (routerQuotes[i].routerType == RouterType.V3 && splitConfig.enableIntraRouterSplit) {
                address factory = v3RouterToFactory[routerQuotes[i].router];
                if (factory != address(0)) {
                    (FeeTierQuote[] memory tierQuotes, uint16[] memory tierPcts, uint256 tierOut) = 
                        _calculateIntraRouterSplit(routerQuotes[i].router, factory, path[0], path[1], routerAmount);

                    if (tierQuotes.length > 0 && tierOut > 0) {
                        strategies[i].internalSplits = new InternalSplit[](tierQuotes.length);
                        for (uint j = 0; j < tierQuotes.length; j++) {
                            uint24[] memory fees = new uint24[](tierQuotes[j].path.length - 1);
                            fees[0] = tierQuotes[j].feeTier;

                            strategies[i].internalSplits[j] = InternalSplit({
                                path: tierQuotes[j].path,
                                v3Fees: fees,
                                percentageBPS: tierPcts[j],
                                amountOut: tierQuotes[j].amountOut,
                                priceImpact: tierQuotes[j].priceImpact
                            });
                        }
                        strategies[i].expectedOutput = tierOut;
                        strategies[i].averageImpact = _calculateWeightedImpact(tierQuotes, tierPcts);
                        totalExpectedOutput += tierOut;
                        continue;
                    }
                }
            }

            // Fallback: single internal split with best quote
            strategies[i].internalSplits = new InternalSplit[](1);
            uint24[] memory fees = new uint24[](1);
            fees[0] = routerQuotes[i].v3Fee;

            strategies[i].internalSplits[0] = InternalSplit({
                path: routerQuotes[i].path,
                v3Fees: fees,
                percentageBPS: 10000,
                amountOut: routerQuotes[i].amountOut,
                priceImpact: routerQuotes[i].priceImpact
            });

            // Recalculate output for actual allocation
            if (routerQuotes[i].routerType == RouterType.V2) {
                try IUniswapV2Router02(routerQuotes[i].router).getAmountsOut(routerAmount, routerQuotes[i].path) returns (uint[] memory amounts) {
                    strategies[i].expectedOutput = amounts[amounts.length - 1];
                } catch {}
            } else {
                address factory = v3RouterToFactory[routerQuotes[i].router];
                if (factory != address(0)) {
                    address pool;
                    try IUniswapV3Factory(factory).getPool(path[0], path[1], routerQuotes[i].v3Fee) returns (address p) {
                        pool = p;
                    } catch {}
                    if (pool != address(0)) {
                        (uint256 out, ) = _calculateV3SwapOutput(pool, routerAmount, path[0], routerQuotes[i].v3Fee);
                        strategies[i].expectedOutput = out;
                    }
                }
            }

            strategies[i].averageImpact = routerQuotes[i].priceImpact;
            totalExpectedOutput += strategies[i].expectedOutput;
        }

        // Calculate weighted price impact
        for (uint i = 0; i < numRouters; i++) {
            weightedPriceImpact += (strategies[i].averageImpact * routerPercentages[i]) / 10000;
        }
    }

    /// @notice Calculate weighted average impact from fee tier quotes
    function _calculateWeightedImpact(FeeTierQuote[] memory quotes, uint16[] memory percentages) internal pure returns (uint256) {
        uint256 weightedImpact = 0;
        for (uint i = 0; i < quotes.length; i++) {
            weightedImpact += (quotes[i].priceImpact * percentages[i]) / 10000;
        }
        return weightedImpact;
    }

    // ============ ARBITRAGE DETECTION SCAFFOLD ============

    /// @notice Arbitrage opportunity data
    struct ArbitrageOpportunity {
        address buyRouter;      // Router with lower price (buy here)
        address sellRouter;     // Router with higher price (sell here)
        address tokenIn;        // Base token
        address tokenOut;       // Quote token
        uint256 buyPrice;       // Price on buy router (tokenOut per tokenIn)
        uint256 sellPrice;      // Price on sell router
        uint256 spreadBPS;      // Price spread in basis points
        bool isViable;          // True if spread exceeds threshold
    }

    /// @notice Minimum spread threshold for arbitrage (in basis points)
    uint256 public arbitrageThresholdBPS = 50; // 0.5% default

    /// @notice Set arbitrage detection threshold
    function setArbitrageThreshold(uint256 thresholdBPS) external {
        require(msg.sender == owner, "MonBridgeDex: Only owner");
        require(thresholdBPS <= 1000, "MonBridgeDex: Threshold too high"); // Max 10%
        arbitrageThresholdBPS = thresholdBPS;
    }

    /// @notice Detect cross-router arbitrage opportunities
    /// @dev Compares normalized prices across all routers for a given token pair
    /// @param tokenA First token of the pair
    /// @param tokenB Second token of the pair
    /// @param testAmount Amount to test for price comparison
    /// @return opportunity Best arbitrage opportunity found
    function detectArbitrage(
        address tokenA,
        address tokenB,
        uint256 testAmount
    ) external view returns (ArbitrageOpportunity memory opportunity) {
        if (testAmount == 0) return opportunity;

        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        // Get quotes from all routers
        RouterQuote[] memory quotes = _getBestQuotePerRouter(testAmount, path);

        if (quotes.length < 2) return opportunity; // Need at least 2 routers

        // Find best and worst prices
        uint256 bestOutput = 0;
        uint256 worstOutput = type(uint256).max;
        address bestRouter = address(0);
        address worstRouter = address(0);

        for (uint i = 0; i < quotes.length; i++) {
            if (quotes[i].amountOut > bestOutput) {
                bestOutput = quotes[i].amountOut;
                bestRouter = quotes[i].router;
            }
            if (quotes[i].amountOut < worstOutput && quotes[i].amountOut > 0) {
                worstOutput = quotes[i].amountOut;
                worstRouter = quotes[i].router;
            }
        }

        // Calculate spread in basis points
        if (worstOutput > 0 && bestOutput > worstOutput) {
            uint256 spreadBPS = ((bestOutput - worstOutput) * 10000) / worstOutput;

            opportunity = ArbitrageOpportunity({
                buyRouter: worstRouter,     // Buy where price is lower (less output)
                sellRouter: bestRouter,     // Sell where price is higher (more output)
                tokenIn: tokenA,
                tokenOut: tokenB,
                buyPrice: worstOutput,
                sellPrice: bestOutput,
                spreadBPS: spreadBPS,
                isViable: spreadBPS >= arbitrageThresholdBPS
            });
        }

        return opportunity;
    }

    /// @notice Check multiple pairs for arbitrage opportunities
    /// @dev Returns all viable arbitrage opportunities found
    function scanArbitrageOpportunities(
        address[] calldata tokens,
        uint256 testAmount
    ) external view returns (ArbitrageOpportunity[] memory opportunities) {
        if (tokens.length < 2) return opportunities;

        // Calculate number of pairs: n*(n-1)/2
        uint256 pairCount = (tokens.length * (tokens.length - 1)) / 2;
        ArbitrageOpportunity[] memory tempOpps = new ArbitrageOpportunity[](pairCount);
        uint256 viableCount = 0;

        // Check all token pairs
        for (uint i = 0; i < tokens.length; i++) {
            for (uint j = i + 1; j < tokens.length; j++) {
                ArbitrageOpportunity memory opp = this.detectArbitrage(tokens[i], tokens[j], testAmount);
                if (opp.isViable) {
                    tempOpps[viableCount] = opp;
                    viableCount++;
                }
            }
        }

        // Resize to actual viable count
        opportunities = new ArbitrageOpportunity[](viableCount);
        for (uint i = 0; i < viableCount; i++) {
            opportunities[i] = tempOpps[i];
        }

        return opportunities;
    }

    /// @notice Emit event when arbitrage opportunity is detected during swap
    event ArbitrageDetected(
        address indexed tokenIn,
        address indexed tokenOut,
        address buyRouter,
        address sellRouter,
        uint256 spreadBPS
    );

    /// @notice Find best router with optimal path including multi-hop through all intermediate tokens
    /// @dev ALWAYS checks hop routes even when direct routes exist to find best opportunity
    /// @dev Uses all configured intermediate tokens (WETH, USDC, etc.) for multi-hop routing
    function _getBestRouterWithPath(uint amountIn, address[] memory path) internal view returns (
        address bestRouter,
        uint bestAmountOut,
        RouterType bestRouterType,
        uint24[] memory bestV3Fees,
        uint bestPriceImpact,
        address[] memory bestPath
    ) {
        bestAmountOut = 0;
        bestRouter = address(0);
        bestRouterType = RouterType.V2;
        bestV3Fees = new uint24[](0);
        bestPriceImpact = type(uint).max;
        bestPath = path;

        // Check all V2 routers with direct AND multi-hop paths
        for (uint i = 0; i < routersV2.length; i++) {
            if (!_validateRouter(routersV2[i])) continue;

            // Always try direct path first
            if (_validateV2Path(routersV2[i], path)) {
                (uint256 amountOut, uint256 impact) = _calculateV2SwapOutput(routersV2[i], path, amountIn);

                if (amountOut > 0 && amountOut > bestAmountOut) {
                    bestAmountOut = amountOut;
                    bestRouter = routersV2[i];
                    bestRouterType = RouterType.V2;
                    bestPriceImpact = impact;
                    bestPath = path;
                }
            }

            // ALWAYS try routing through ALL intermediate tokens (not just when direct fails)
            // This ensures we never miss better hop opportunities
            if (path.length == 2) {
                for (uint k = 0; k < intermediateTokens.length; k++) {
                    address intermediateToken = intermediateTokens[k];

                    // Skip if intermediate is same as input or output
                    if (intermediateToken == path[0] || intermediateToken == path[1]) continue;

                    address[] memory hopPath = new address[](3);
                    hopPath[0] = path[0];
                    hopPath[1] = intermediateToken;
                    hopPath[2] = path[1];

                    if (_validateV2Path(routersV2[i], hopPath)) {
                        (uint256 hopAmountOut, uint256 hopImpact) = _calculateV2SwapOutput(routersV2[i], hopPath, amountIn);

                        // Use hop route if it gives better output
                        if (hopAmountOut > 0 && hopAmountOut > bestAmountOut) {
                            bestAmountOut = hopAmountOut;
                            bestRouter = routersV2[i];
                            bestRouterType = RouterType.V2;
                            bestPriceImpact = hopImpact;
                            bestPath = hopPath;
                        }
                    }
                }
            }
        }

        // Check all V3 routers with direct AND multi-hop paths
        for (uint i = 0; i < routersV3.length; i++) {
            if (!_validateRouter(routersV3[i])) continue;

            address factory = v3RouterToFactory[routersV3[i]];
            if (factory == address(0)) continue;

            if (path.length == 2) {
                // Always try direct V3 path
                (address directPool, uint24 directFee, uint directOut, uint directImpact) = _getBestV3Pool(
                    factory,
                    path[0],
                    path[1],
                    amountIn
                );

                if (directPool != address(0) && directOut > 0 && directOut > bestAmountOut) {
                    bestAmountOut = directOut;
                    bestRouter = routersV3[i];
                    bestRouterType = RouterType.V3;
                    bestV3Fees = new uint24[](1);
                    bestV3Fees[0] = directFee;
                    bestPriceImpact = directImpact;
                    bestPath = path;
                }

                // ALWAYS try multi-hop through ALL intermediate tokens
                for (uint k = 0; k < intermediateTokens.length; k++) {
                    address intermediateToken = intermediateTokens[k];

                    // Skip if intermediate is same as input or output
                    if (intermediateToken == path[0] || intermediateToken == path[1]) continue;

                    address[] memory hopPath = new address[](3);
                    hopPath[0] = path[0];
                    hopPath[1] = intermediateToken;
                    hopPath[2] = path[1];

                    (address pool1, uint24 fee1, uint amountMid, uint impact1) = _getBestV3Pool(
                        factory,
                        hopPath[0],
                        hopPath[1],
                        amountIn
                    );

                    if (pool1 != address(0) && amountMid > 0) {
                        (address pool2, uint24 fee2, uint hopOut, uint impact2) = _getBestV3Pool(
                            factory,
                            hopPath[1],
                            hopPath[2],
                            amountMid
                        );

                        if (pool2 != address(0) && hopOut > 0 && hopOut > bestAmountOut) {
                            bestAmountOut = hopOut;
                            bestRouter = routersV3[i];
                            bestRouterType = RouterType.V3;
                            bestV3Fees = new uint24[](2);
                            bestV3Fees[0] = fee1;
                            bestV3Fees[1] = fee2;
                            bestPriceImpact = impact1 + impact2;
                            bestPath = hopPath;
                        }
                    }
                }
            }
        }

        // Fallback: if no route found, try any valid path
        if (bestRouter == address(0)) {
            for (uint i = 0; i < routersV2.length; i++) {
                if (_validateRouter(routersV2[i]) && _validateV2Path(routersV2[i], path)) {
                    bestRouter = routersV2[i];
                    bestRouterType = RouterType.V2;
                    bestPath = path;
                    bestAmountOut = 1;
                    break;
                }
            }

            if (bestRouter == address(0)) {
                for (uint i = 0; i < routersV3.length; i++) {
                    if (_validateRouter(routersV3[i])) {
                        address factory = v3RouterToFactory[routersV3[i]];
                        if (factory != address(0) && path.length == 2) {
                            for (uint j = 0; j < v3FeeTiers.length; j++) {
                                if (_v3PoolExists(factory, path[0], path[1], v3FeeTiers[j])) {
                                    bestRouter = routersV3[i];
                                    bestRouterType = RouterType.V3;
                                    bestPath = path;
                                    bestV3Fees = new uint24[](1);
                                    bestV3Fees[0] = v3FeeTiers[j];
                                    bestAmountOut = 1;
                                    break;
                                }
                            }
                            if (bestRouter != address(0)) break;
                        }
                    }
                }
            }
        }

        require(bestRouter != address(0), "MonBridgeDex: No valid route found - check token addresses and pool liquidity");
    }

    /// @notice Execute split swap across multiple routers
    /// @dev All splits must have the same input token and swap type
    function executeSplit(SplitSwapData calldata splitData)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint totalAmountOut)
    {
        require(splitData.splits.length >= 2 && splitData.splits.length <= 4, "MonBridgeDex: Invalid split count (2-4)");
        require(splitData.totalAmountIn > 0, "MonBridgeDex: Amount must be greater than 0");

        // Validate tokens in all paths and ensure all splits use the same input token
        address inputToken = splitData.splits[0].path[0];
        SwapType swapType = splitData.splits[0].swapType;
        address outputToken = splitData.splits[0].path[splitData.splits[0].path.length - 1];

        for (uint i = 0; i < splitData.splits.length; i++) {
            require(splitData.splits[i].path[0] == inputToken, "MonBridgeDex: All splits must have same input token");
            require(splitData.splits[i].swapType == swapType, "MonBridgeDex: All splits must have same swap type");
            for (uint j = 0; j < splitData.splits[i].path.length; j++) {
                require(!tokenBlacklist[splitData.splits[i].path[j]], "MonBridgeDex: Token blacklisted");
            }
        }

        // Validate that split amounts sum to total
        uint splitSum = 0;
        for (uint i = 0; i < splitData.splits.length; i++) {
            splitSum += splitData.splits[i].amountIn;
        }
        require(splitSum == splitData.totalAmountIn, "MonBridgeDex: Split amounts must sum to total");

        // Calculate fee at total level (not per-split to avoid rounding issues)
        uint totalFee = splitData.totalAmountIn / FEE_DIVISOR;
        uint totalAmountForSwap = splitData.totalAmountIn - totalFee;

        // CRITICAL: Pull ALL tokens from user upfront before any split execution
        // because _executeSwapInternal is called via this.func() which changes msg.sender
        if (swapType == SwapType.ETH_TO_TOKEN) {
            require(inputToken == WETH, "MonBridgeDex: Path must start with WETH for ETH swap");
            require(msg.value == splitData.totalAmountIn, "MonBridgeDex: Incorrect ETH amount sent");
            feeAccumulatedETH += totalFee;
        } else {
            // TOKEN_TO_ETH or TOKEN_TO_TOKEN: pull all tokens from user at once
            require(
                IERC20(inputToken).transferFrom(msg.sender, address(this), splitData.totalAmountIn),
                "MonBridgeDex: Token transfer from user failed"
            );
            feeAccumulatedTokens[inputToken] += totalFee;
        }

        uint balanceBefore;
        if (swapType == SwapType.TOKEN_TO_ETH) {
            balanceBefore = msg.sender.balance;
        } else {
            balanceBefore = IERC20(outputToken).balanceOf(msg.sender);
        }

        // Execute each split - tokens are already in the contract
        // Distribute the post-fee amount proportionally to each split
        uint usedAmount = 0;
        for (uint i = 0; i < splitData.splits.length; i++) {
            SwapData memory split = splitData.splits[i];

            require(
                (split.routerType == RouterType.V2 && isRouterV2[split.router]) ||
                (split.routerType == RouterType.V3 && isRouterV3[split.router]),
                "MonBridgeDex: Router not whitelisted"
            );
            require(_validateRouter(split.router), "MonBridgeDex: Router unhealthy");

            // Calculate proportional amount for this split (no per-split fee to avoid rounding issues)
            // For the last split, use remaining amount to avoid rounding errors
            uint amountForSwap;
            if (i == splitData.splits.length - 1) {
                amountForSwap = totalAmountForSwap - usedAmount;
            } else {
                amountForSwap = (split.amountIn * totalAmountForSwap) / splitData.totalAmountIn;
                usedAmount += amountForSwap;
            }

            try this._executeSwapInternal(split, amountForSwap, msg.sender) {
                _recordSwapSuccess(split.router, amountForSwap);
            } catch Error(string memory reason) {
                _recordSwapFailure(split.router);
                revert(string(abi.encodePacked("MonBridgeDex: Split ", uint2str(i), " failed - ", reason)));
            } catch {
                _recordSwapFailure(split.router);
                revert(string(abi.encodePacked("MonBridgeDex: Split ", uint2str(i), " failed")));
            }
        }

        uint balanceAfter;
        if (swapType == SwapType.TOKEN_TO_ETH) {
            balanceAfter = msg.sender.balance;
        } else {
            balanceAfter = IERC20(outputToken).balanceOf(msg.sender);
        }

        totalAmountOut = balanceAfter - balanceBefore;
        require(totalAmountOut >= splitData.totalAmountOutMin, "MonBridgeDex: Insufficient total output");

        emit SplitSwapExecuted(
            msg.sender,
            inputToken,
            outputToken,
            splitData.totalAmountIn,
            totalAmountOut,
            splitData.splits.length,
            totalFee
        );
    }

    /// @notice Helper to convert uint to string
    function uint2str(uint _i) internal pure returns (string memory) {
        if (_i == 0) return "0";
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    /// @notice Execute swap with provided swap data
    function execute(SwapData calldata swapData)
        external
        payable
        nonReentrant
        whenNotPaused
        validTokens(swapData.path)
        returns (uint amountOut)
    {
        require(
            (swapData.routerType == RouterType.V2 && isRouterV2[swapData.router]) ||
            (swapData.routerType == RouterType.V3 && isRouterV3[swapData.router]),
            "MonBridgeDex: Router not whitelisted for specified type"
        );
        require(swapData.path.length >= 2, "MonBridgeDex: Invalid swap path, must have at least 2 tokens");
        require(swapData.deadline >= block.timestamp, "MonBridgeDex: Transaction deadline has expired");
        require(_validateRouter(swapData.router), "MonBridgeDex: Router is unhealthy or disabled");
        require(swapData.amountIn > 0, "MonBridgeDex: Swap amount must be greater than 0");

        // Validate V3 fee array matches path length
        if (swapData.routerType == RouterType.V3) {
            require(
                swapData.v3Fees.length == swapData.path.length - 1,
                "MonBridgeDex: V3 fees array must match path length"
            );
        }

        uint fee = swapData.amountIn / FEE_DIVISOR;
        uint amountForSwap = swapData.amountIn - fee;

        // CRITICAL: Pull tokens from user HERE before calling _executeSwapInternal
        // because _executeSwapInternal is called via this.func() which changes msg.sender
        if (swapData.swapType == SwapType.ETH_TO_TOKEN) {
            require(swapData.path[0] == WETH, "MonBridgeDex: Path must start with WETH for ETH swap");
            require(msg.value == swapData.amountIn, "MonBridgeDex: Incorrect ETH amount sent");
            feeAccumulatedETH += fee;
        } else {
            // TOKEN_TO_ETH or TOKEN_TO_TOKEN: pull tokens from user
            require(
                IERC20(swapData.path[0]).transferFrom(msg.sender, address(this), swapData.amountIn),
                "MonBridgeDex: Token transfer from user failed"
            );
            feeAccumulatedTokens[swapData.path[0]] += fee;
        }

        uint balanceBefore;
        address outputToken = swapData.path[swapData.path.length - 1];

        if (swapData.swapType == SwapType.TOKEN_TO_ETH) {
            balanceBefore = msg.sender.balance;
        } else {
            balanceBefore = IERC20(outputToken).balanceOf(msg.sender);
        }

        try this._executeSwapInternal(swapData, amountForSwap, msg.sender) returns (uint result) {
            amountOut = result;
            _recordSwapSuccess(swapData.router, amountForSwap);
        } catch Error(string memory reason) {
            _recordSwapFailure(swapData.router);
            revert(string(abi.encodePacked("MonBridgeDex: Swap failed - ", reason)));
        } catch (bytes memory) {
            _recordSwapFailure(swapData.router);
            revert("MonBridgeDex: Swap execution failed with unknown error");
        }

        uint balanceAfter;
        if (swapData.swapType == SwapType.TOKEN_TO_ETH) {
            balanceAfter = msg.sender.balance;
        } else {
            balanceAfter = IERC20(outputToken).balanceOf(msg.sender);
        }

        uint actualOut = balanceAfter - balanceBefore;
        require(actualOut >= swapData.amountOutMin, "MonBridgeDex: Insufficient output amount, exceeds slippage tolerance");

        emit SwapExecuted(
            msg.sender,
            swapData.router,
            swapData.path[0],
            swapData.path[swapData.path.length - 1],
            amountForSwap,
            actualOut,
            fee,
            0,
            swapData.swapType
        );
    }

    /// @notice Internal swap execution (called via try-catch)
    /// @param swapData The swap parameters
    /// @param amountForSwap Amount after fee deduction
    /// @param recipient The original caller who should receive the output tokens
    function _executeSwapInternal(SwapData calldata swapData, uint amountForSwap, address recipient)
        external
        returns (uint amountOut)
    {
        require(msg.sender == address(this), "Internal only");

        if (swapData.routerType == RouterType.V2) {
            return _executeV2Swap(swapData, amountForSwap, recipient);
        } else {
            return _executeV3Swap(swapData, amountForSwap, recipient);
        }
    }

    /// @notice Execute V2 swap with fallback to NATIVE naming convention
    /// @dev Some V2 forks use swapExactNATIVEForTokens instead of swapExactETHForTokens
    function _executeV2Swap(SwapData calldata swapData, uint amountForSwap, address recipient) internal returns (uint amountOut) {
        if (swapData.swapType == SwapType.ETH_TO_TOKEN) {
            // Try standard ETH methods first, fallback to NATIVE methods
            if (swapData.supportFeeOnTransfer) {
                if (!_trySwapExactETHForTokensFOT(swapData.router, amountForSwap, swapData.amountOutMin, swapData.path, recipient, swapData.deadline)) {
                    // Fallback to NATIVE naming
                    IV2RouterNative(swapData.router).swapExactNATIVEForTokensSupportingFeeOnTransferTokens{value: amountForSwap}(
                        swapData.amountOutMin,
                        swapData.path,
                        recipient,
                        swapData.deadline
                    );
                }
            } else {
                (bool success, uint[] memory amounts) = _trySwapExactETHForTokens(
                    swapData.router, amountForSwap, swapData.amountOutMin, swapData.path, recipient, swapData.deadline
                );
                if (success) {
                    amountOut = amounts[amounts.length - 1];
                } else {
                    // Fallback to NATIVE naming
                    amounts = IV2RouterNative(swapData.router).swapExactNATIVEForTokens{value: amountForSwap}(
                        swapData.amountOutMin,
                        swapData.path,
                        recipient,
                        swapData.deadline
                    );
                    amountOut = amounts[amounts.length - 1];
                }
            }

        } else if (swapData.swapType == SwapType.TOKEN_TO_ETH) {
            require(swapData.path[swapData.path.length - 1] == WETH, "Path must end with WETH");
            _safeApprove(swapData.path[0], swapData.router, amountForSwap);

            if (swapData.supportFeeOnTransfer) {
                if (!_trySwapExactTokensForETHFOT(swapData.router, amountForSwap, swapData.amountOutMin, swapData.path, recipient, swapData.deadline)) {
                    // Fallback to NATIVE naming
                    IV2RouterNative(swapData.router).swapExactTokensForNATIVESupportingFeeOnTransferTokens(
                        amountForSwap,
                        swapData.amountOutMin,
                        swapData.path,
                        recipient,
                        swapData.deadline
                    );
                }
            } else {
                (bool success, uint[] memory amounts) = _trySwapExactTokensForETH(
                    swapData.router, amountForSwap, swapData.amountOutMin, swapData.path, recipient, swapData.deadline
                );
                if (success) {
                    amountOut = amounts[amounts.length - 1];
                } else {
                    // Fallback to NATIVE naming
                    amounts = IV2RouterNative(swapData.router).swapExactTokensForNATIVE(
                        amountForSwap,
                        swapData.amountOutMin,
                        swapData.path,
                        recipient,
                        swapData.deadline
                    );
                    amountOut = amounts[amounts.length - 1];
                }
            }

        } else {
            // TOKEN_TO_TOKEN: Standard swap, no NATIVE variant needed
            _safeApprove(swapData.path[0], swapData.router, amountForSwap);

            if (swapData.supportFeeOnTransfer) {
                IUniswapV2Router02(swapData.router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    amountForSwap,
                    swapData.amountOutMin,
                    swapData.path,
                    recipient,
                    swapData.deadline
                );
            } else {
                uint[] memory amounts = IUniswapV2Router02(swapData.router).swapExactTokensForTokens(
                    amountForSwap,
                    swapData.amountOutMin,
                    swapData.path,
                    recipient,
                    swapData.deadline
                );
                amountOut = amounts[amounts.length - 1];
            }
        }
    }

    /// @notice Try standard swapExactETHForTokens, return success status
    function _trySwapExactETHForTokens(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to,
        uint deadline
    ) internal returns (bool success, uint[] memory amounts) {
        try IUniswapV2Router02(router).swapExactETHForTokens{value: amountIn}(
            amountOutMin, path, to, deadline
        ) returns (uint[] memory result) {
            return (true, result);
        } catch {
            return (false, amounts);
        }
    }

    /// @notice Try standard swapExactETHForTokensSupportingFeeOnTransferTokens
    function _trySwapExactETHForTokensFOT(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to,
        uint deadline
    ) internal returns (bool success) {
        try IUniswapV2Router02(router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountIn}(
            amountOutMin, path, to, deadline
        ) {
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Try standard swapExactTokensForETH, return success status
    function _trySwapExactTokensForETH(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to,
        uint deadline
    ) internal returns (bool success, uint[] memory amounts) {
        try IUniswapV2Router02(router).swapExactTokensForETH(
            amountIn, amountOutMin, path, to, deadline
        ) returns (uint[] memory result) {
            return (true, result);
        } catch {
            return (false, amounts);
        }
    }

    /// @notice Try standard swapExactTokensForETHSupportingFeeOnTransferTokens
    function _trySwapExactTokensForETHFOT(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to,
        uint deadline
    ) internal returns (bool success) {
        try IUniswapV2Router02(router).swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn, amountOutMin, path, to, deadline
        ) {
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Encode V3 multi-hop path for exactInput
    /// @dev Path format: token0 | fee01 | token1 | fee12 | token2 | ...
    /// Example: USDC -> 500 -> WETH -> 3000 -> DAI
    function _encodeV3Path(address[] memory tokens, uint24[] memory fees) internal pure returns (bytes memory path) {
        require(tokens.length >= 2, "MonBridgeDex: Invalid path length");
        require(tokens.length == fees.length + 1, "MonBridgeDex: Path/fee array mismatch");

        // Start with first token
        path = abi.encodePacked(tokens[0]);

        // Append each (fee, token) pair
        for (uint i = 0; i < fees.length; i++) {
            path = abi.encodePacked(path, fees[i], tokens[i + 1]);
        }
    }

    /// @notice Execute V3 swap (supports multi-hop)
    /// @dev Token transfers and fee accumulation are handled in execute() before this is called
    function _executeV3Swap(SwapData calldata swapData, uint amountForSwap, address recipient) internal returns (uint amountOut) {
        if (swapData.swapType == SwapType.ETH_TO_TOKEN) {
            // ETH was already validated and fee accumulated in execute()
            // V3 requires WETH, so wrap ETH first
            IWETH(WETH).deposit{value: amountForSwap}();
            _safeApprove(WETH, swapData.router, amountForSwap);

            if (swapData.path.length == 2) {
                ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                    tokenIn: swapData.path[0],
                    tokenOut: swapData.path[1],
                    fee: swapData.v3Fees[0],
                    recipient: recipient,
                    deadline: swapData.deadline,
                    amountIn: amountForSwap,
                    amountOutMinimum: swapData.amountOutMin,
                    sqrtPriceLimitX96: 0
                });

                amountOut = ISwapRouter(swapData.router).exactInputSingle(params);
            } else {
                bytes memory path = _encodeV3Path(swapData.path, swapData.v3Fees);

                ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
                    path: path,
                    recipient: recipient,
                    deadline: swapData.deadline,
                    amountIn: amountForSwap,
                    amountOutMinimum: swapData.amountOutMin
                });

                amountOut = ISwapRouter(swapData.router).exactInput(params);
            }

        } else if (swapData.swapType == SwapType.TOKEN_TO_ETH) {
            require(swapData.path[swapData.path.length - 1] == WETH, "MonBridgeDex: Path must end with WETH");
            // Tokens already transferred to contract and fee accumulated in execute()
            _safeApprove(swapData.path[0], swapData.router, amountForSwap);

            if (swapData.path.length == 2) {
                ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                    tokenIn: swapData.path[0],
                    tokenOut: swapData.path[1],
                    fee: swapData.v3Fees[0],
                    recipient: address(this),
                    deadline: swapData.deadline,
                    amountIn: amountForSwap,
                    amountOutMinimum: swapData.amountOutMin,
                    sqrtPriceLimitX96: 0
                });

                amountOut = ISwapRouter(swapData.router).exactInputSingle(params);
            } else {
                bytes memory path = _encodeV3Path(swapData.path, swapData.v3Fees);

                ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
                    path: path,
                    recipient: address(this),
                    deadline: swapData.deadline,
                    amountIn: amountForSwap,
                    amountOutMinimum: swapData.amountOutMin
                });

                amountOut = ISwapRouter(swapData.router).exactInput(params);
            }

            // V3 outputs WETH for TOKEN_TO_ETH, need to unwrap and send to recipient
            IWETH(WETH).withdraw(amountOut);
            payable(recipient).transfer(amountOut);

        } else {
            // TOKEN_TO_TOKEN: Tokens already transferred to contract and fee accumulated in execute()
            _safeApprove(swapData.path[0], swapData.router, amountForSwap);

            if (swapData.path.length == 2) {
                ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                    tokenIn: swapData.path[0],
                    tokenOut: swapData.path[1],
                    fee: swapData.v3Fees[0],
                    recipient: recipient,
                    deadline: swapData.deadline,
                    amountIn: amountForSwap,
                    amountOutMinimum: swapData.amountOutMin,
                    sqrtPriceLimitX96: 0
                });

                amountOut = ISwapRouter(swapData.router).exactInputSingle(params);
            } else {
                bytes memory path = _encodeV3Path(swapData.path, swapData.v3Fees);

                ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
                    path: path,
                    recipient: recipient,
                    deadline: swapData.deadline,
                    amountIn: amountForSwap,
                    amountOutMinimum: swapData.amountOutMin
                });

                amountOut = ISwapRouter(swapData.router).exactInput(params);
            }
        }
    }

    /// @notice Record successful swap
    function _recordSwapSuccess(address router, uint256 volume) internal {
        routerInfo[router].lastSuccessfulSwap = block.timestamp;
        routerInfo[router].totalVolume += volume;
        routerInfo[router].failureCount = 0;
    }

    /// @notice Record swap failure
    function _recordSwapFailure(address router) internal {
        routerInfo[router].failureCount++;
        emit RouterHealthUpdate(router, routerInfo[router].isActive, routerInfo[router].failureCount);
    }

    /// @notice Mark token as fee-on-transfer
    function markFeeOnTransferToken(address token, uint256 feeBPS) external onlyOwner {
        isFeeOnTransferToken[token] = true;
        lastKnownTransferFee[token] = feeBPS;
    }

    /// @notice Update slippage configuration
    function updateSlippageConfig(
        uint16 _baseSlippageBPS,
        uint16 _impactMultiplier,
        uint16 _maxSlippageBPS
    ) external onlyOwner {
        require(_maxSlippageBPS <= 1000, "MonBridgeDex: Max slippage too high");
        slippageConfig = SlippageConfig({
            baseSlippageBPS: _baseSlippageBPS,
            impactMultiplier: _impactMultiplier,
            maxSlippageBPS: _maxSlippageBPS
        });
    }

    /// @notice Update liquidity validation config
    function updateLiquidityConfig(
        uint256 _minLiquidityUSD,
        bool _requireLiquidityCheck
    ) external onlyOwner {
        liquidityConfig = LiquidityConfig({
            minLiquidityUSD: _minLiquidityUSD,
            requireLiquidityCheck: _requireLiquidityCheck
        });
    }

    /// @notice Update TWAP oracle config
    function updateTWAPConfig(
        uint32 _twapInterval,
        uint16 _maxPriceDeviationBPS,
        bool _enableTWAPCheck
    ) external onlyOwner {
        require(_maxPriceDeviationBPS <= 2000, "MonBridgeDex: Max deviation too high");
        twapConfig = TWAPConfig({
            twapInterval: _twapInterval,
            maxPriceDeviationBPS: _maxPriceDeviationBPS,
            enableTWAPCheck: _enableTWAPCheck
        });
    }

    /// @notice Update split trade configuration
    function updateSplitConfig(
        bool _enableAutoSplit,
        uint16 _minSplitImpactBPS,
        uint8 _maxSplits,
        bool _alwaysSplit,
        bool _enableIntraRouterSplit
    ) external onlyOwner {
        require(_maxSplits >= 2 && _maxSplits <= 4, "MonBridgeDex: Max splits must be 2-4");
        splitConfig = SplitConfig({
            enableAutoSplit: _enableAutoSplit,
            minSplitImpactBPS: _minSplitImpactBPS,
            maxSplits: _maxSplits,
            alwaysSplit: _alwaysSplit,
            enableIntraRouterSplit: _enableIntraRouterSplit
        });
    }

    /// @notice Enable/disable router
    function setRouterActive(address router, bool active) external onlyOwner {
        routerInfo[router].isActive = active;
        if (active) {
            routerInfo[router].failureCount = 0;
        }
        emit RouterHealthUpdate(router, active, routerInfo[router].failureCount);
    }

    /// @notice Blacklist/unblacklist token
    function setTokenBlacklist(address token, bool blacklisted) external onlyOwner {
        tokenBlacklist[token] = blacklisted;
    }

    /// @notice Pause contract
    function pause() external onlyOwner {
        paused = true;
    }

    /// @notice Unpause contract
    function unpause() external onlyOwner {
        paused = false;
    }

    /// @notice Get price impact for V2 router
    function getPriceImpact(address router, address tokenIn, address tokenOut, uint amountIn) external view returns (uint priceImpact) {
        require(isRouterV2[router], "Not a V2 router");
        address factory = IUniswapV2Router02(router).factory();
        address pair = IUniswapV2Factory(factory).getPair(tokenIn, tokenOut);
        require(pair != address(0), "Pair not found");

        (uint reserve0, uint reserve1, ) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        uint reserveIn;
        uint reserveOut;
        if (tokenIn == token0) {
            reserveIn = reserve0;
            reserveOut = reserve1;
        } else {
            reserveIn = reserve1;
            reserveOut = reserve0;
        }

        uint idealOutput = (amountIn * reserveOut) / reserveIn;

        address[] memory path = getPath(tokenIn, tokenOut);
        uint[] memory amounts = IUniswapV2Router02(router).getAmountsOut(amountIn, path);
        uint actualOutput = amounts[amounts.length - 1];

        if (idealOutput > actualOutput) {
            priceImpact = ((idealOutput - actualOutput) * 1e18) / idealOutput;
        } else {
            priceImpact = 0;
        }
    }

    /// @notice Get price impact for V3 pool
    function getV3PriceImpact(address router, address tokenIn, address tokenOut, uint24 fee, uint amountIn) external view returns (uint priceImpact) {
        require(isRouterV3[router], "Not a V3 router");
        address factory = v3RouterToFactory[router];
        address pool = IUniswapV3Factory(factory).getPool(tokenIn, tokenOut, fee);
        require(pool != address(0), "Pool not found");

        (, priceImpact) = _calculateV3SwapOutput(pool, amountIn, tokenIn, fee);
    }

    function getPath(address tokenIn, address tokenOut) public pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        return path;
    }

    function withdrawFeesETH() external onlyOwner {
        uint amount = feeAccumulatedETH;
        require(amount > 0, "No ETH fees");
        feeAccumulatedETH = 0;
        payable(owner).transfer(amount);
        emit FeesWithdrawn(owner, amount);
    }

    function withdrawFeesToken(address token) external onlyOwner {
        uint amount = feeAccumulatedTokens[token];
        require(amount > 0, "No token fees");
        feeAccumulatedTokens[token] = 0;
        require(IERC20(token).transfer(owner, amount), "Transfer failed");
        emit TokenFeesWithdrawn(owner, token, amount);
    }

    function withdrawAllTokenFees(address[] calldata tokens) external onlyOwner {
        for (uint i = 0; i < tokens.length; i++) {
            uint amount = feeAccumulatedTokens[tokens[i]];
            if (amount > 0) {
                feeAccumulatedTokens[tokens[i]] = 0;
                require(IERC20(tokens[i]).transfer(owner, amount), "MonBridgeDex: Fee withdrawal failed");
                emit TokenFeesWithdrawn(owner, tokens[i], amount);
            }
        }
    }

    /// @notice Withdraw all token balances (fees + any stuck tokens)
    function withdrawAllTokens(address[] calldata tokens) external onlyOwner {
        for (uint i = 0; i < tokens.length; i++) {
            uint balance = IERC20(tokens[i]).balanceOf(address(this));
            if (balance > 0) {
                // Reset fee tracking if withdrawing fees
                if (feeAccumulatedTokens[tokens[i]] > 0) {
                    feeAccumulatedTokens[tokens[i]] = 0;
                }
                require(IERC20(tokens[i]).transfer(owner, balance), "MonBridgeDex: Token withdrawal failed");
                emit TokenFeesWithdrawn(owner, tokens[i], balance);
            }
        }
    }

    /// @notice Withdraw all ETH balance (fees + any stuck ETH)
    function withdrawAllETH() external onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "MonBridgeDex: No ETH to withdraw");
        feeAccumulatedETH = 0;
        payable(owner).transfer(balance);
        emit FeesWithdrawn(owner, balance);
    }

    function emergencyWithdraw(address token, uint amount) external onlyOwner {
        if (token == address(0)) {
            require(amount <= address(this).balance, "MonBridgeDex: Insufficient ETH balance");
            payable(owner).transfer(amount);
        } else {
            require(amount <= IERC20(token).balanceOf(address(this)), "MonBridgeDex: Insufficient token balance");
            require(IERC20(token).transfer(owner, amount), "MonBridgeDex: Emergency withdrawal failed");
        }
    }

    receive() external payable {}

    /// @notice DEBUG: Get detailed quote calculation info (shows why quote might fail)
    /// @dev Returns exact outputs the contract calculates internally
    function debugGetQuote(
        uint amountIn,
        address[] calldata path
    ) external view returns (
        uint v2BestOut,
        uint v3BestOut,
        uint finalBestOut,
        address finalBestRouter,
        string memory debugInfo
    ) {
        require(path.length >= 2, "Invalid path");
        require(amountIn > 0, "Amount must be > 0");

        uint fee = amountIn / FEE_DIVISOR;
        uint amountForSwap = amountIn - fee;

        // Track V2
        uint v2Best = 0;
        for (uint i = 0; i < routersV2.length; i++) {
            if (!_validateRouter(routersV2[i])) continue;
            if (!_validateV2Path(routersV2[i], path)) continue;

            try IUniswapV2Router02(routersV2[i]).getAmountsOut(amountForSwap, path) returns (uint[] memory amounts) {
                uint out = amounts[amounts.length - 1];
                if (out > v2Best) v2Best = out;
            } catch {}
        }
        v2BestOut = v2Best;

        // Track V3
        uint v3Best = 0;
        address v3Router = address(0);
        for (uint i = 0; i < routersV3.length; i++) {
            if (!_validateRouter(routersV3[i])) continue;
            address factory = v3RouterToFactory[routersV3[i]];
            if (factory == address(0)) continue;

            if (path.length == 2) {
                (address bestPool, uint24 bestFee, uint amountOut, ) = _getBestV3Pool(factory, path[0], path[1], amountForSwap);
                if (bestPool != address(0) && amountOut > v3Best) {
                    v3Best = amountOut;
                    v3Router = routersV3[i];
                }
            }
        }
        v3BestOut = v3Best;

        // Determine final best
        if (v2Best > v3Best && v2Best > 0) {
            finalBestOut = v2Best;
            finalBestRouter = routersV2[0];
            debugInfo = "V2 is best";
        } else if (v3Best > 0) {
            finalBestOut = v3Best;
            finalBestRouter = v3Router;
            debugInfo = "V3 is best";
        } else {
            debugInfo = "NO ROUTES FOUND";
        }
    }
}

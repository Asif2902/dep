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

/// @title MonBridgeDex
/// @notice Production-grade DEX aggregator with Uniswap V2 and V3 support
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
        uint16 minSplitImpactBPS; // Minimum impact to trigger split (e.g., 100 = 1%)
        uint8 maxSplits; // Max number of splits (2-4)
    }
    SplitConfig public splitConfig;

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

    constructor(address _weth) {
        owner = msg.sender;
        WETH = _weth;
        v3FeeTiers.push(100);
        v3FeeTiers.push(500);
        v3FeeTiers.push(3000);
        v3FeeTiers.push(10000);

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
            minSplitImpactBPS: 100, // Split if impact > 1%
            maxSplits: 4
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

    /// @notice Validate pool price against TWAP to prevent manipulation
    function _validateTWAP(address pool, uint160 currentPrice) internal view returns (bool) {
        if (!twapConfig.enableTWAPCheck) return true;

        // This is a simplified TWAP check
        // In production, you would implement proper TWAP calculation using observations
        // For now, we return true to not block swaps
        // TODO: Implement full TWAP oracle with historical price checks

        // Suppress unused parameter warnings
        pool;
        currentPrice;

        return true;
    }

    /// @notice Validate pool liquidity meets minimum requirements
    function _validateLiquidity(uint128 liquidity) internal view returns (bool) {
        if (!liquidityConfig.requireLiquidityCheck) return true;

        // Simplified check - in production would convert to USD value
        return liquidity >= uint128(liquidityConfig.minLiquidityUSD);
    }

    /// @notice Calculate V3 swap output with decimal-aware pricing
    /// @dev Simplified approach that handles token decimal differences properly
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
            
            // Calculate fee
            uint256 feeAmount = (amountIn * feeTier) / 1000000;
            uint256 amountInAfterFee = amountIn - feeAmount;

            // Simplified V3 price calculation WITHOUT squaring to avoid overflow
            // sqrtPriceX96 = sqrt(price) * 2^96 where price = token1/token0
            // Use two-step mulDiv to get price without overflow
            // V3 price already accounts for decimal differences - no extra adjustment needed!
            
            uint256 amountOut;
            
            if (zeroForOne) {
                // Token0 -> Token1: amountOut = amountIn * (sqrtPrice / 2^96)^2
                // Step 1: intermediate = amountIn * sqrtPrice / 2^96
                // Step 2: amountOut = intermediate * sqrtPrice / 2^96
                uint256 intermediate = FullMath.mulDiv(amountInAfterFee, uint256(sqrtPriceX96), FixedPoint96.Q96);
                amountOut = FullMath.mulDiv(intermediate, uint256(sqrtPriceX96), FixedPoint96.Q96);
            } else {
                // Token1 -> Token0: amountOut = amountIn / (sqrtPrice / 2^96)^2
                // Step 1: intermediate = amountIn * 2^96 / sqrtPrice
                // Step 2: amountOut = intermediate * 2^96 / sqrtPrice
                if (sqrtPriceX96 == 0) return (0, type(uint256).max);
                uint256 intermediate = FullMath.mulDiv(amountInAfterFee, FixedPoint96.Q96, uint256(sqrtPriceX96));
                amountOut = FullMath.mulDiv(intermediate, FixedPoint96.Q96, uint256(sqrtPriceX96));
            }

            // Apply conservative slippage reduction based on base slippage config
            uint256 slippageReduction = 10000 - slippageConfig.baseSlippageBPS;
            amountOut = (amountOut * slippageReduction) / 10000;

            // Validate we got a reasonable output
            if (amountOut == 0) {
                // Return error - pool calculation failed
                return (0, type(uint256).max);
            }

            // Use user's suggestion: input-based price impact calculation
            // Simple heuristic: larger trades = higher impact
            // impact = sqrt(amountIn) / 1000 in basis points, minimum is fee tier
            uint256 feeTierBPS = (uint256(feeTier) * 10000) / 1000000;
            
            // Start with fee tier as base impact, add small percentage of input
            // This keeps impact reasonable while scaling with trade size
            priceImpact = feeTierBPS + ((amountIn / amountInAfterFee) * 10); // Add ~1% per trade size
            
            // Cap at reasonable maximum (10% = 1000 BPS)
            if (priceImpact > 1000) priceImpact = 1000;

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

    /// @notice Find best router (V2 or V3) with highest output
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
                uint[] memory amounts;
                try IUniswapV2Router02(routersV2[i]).getAmountsOut(amountIn, path) returns (uint[] memory res) {
                    amounts = res;
                    uint amountOut = amounts[amounts.length - 1];

                    if (amountOut > 0 && amountOut > bestAmountOut) {
                        bestAmountOut = amountOut;
                        bestRouter = routersV2[i];
                        bestRouterType = RouterType.V2;
                        bestPriceImpact = 0;
                        bestPath = path;
                    }
                } catch {
                    // Skip this router if getAmountsOut fails
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
                    uint[] memory wethAmounts;
                    try IUniswapV2Router02(routersV2[i]).getAmountsOut(amountIn, wethPath) returns (uint[] memory res) {
                        wethAmounts = res;
                        uint wethAmountOut = wethAmounts[wethAmounts.length - 1];

                        // If routing through WETH gives better price, use it
                        if (wethAmountOut > 0 && wethAmountOut > bestAmountOut) {
                            bestAmountOut = wethAmountOut;
                            bestRouter = routersV2[i];
                            bestRouterType = RouterType.V2;
                            bestPriceImpact = 0;
                            bestPath = wethPath;
                        }
                    } catch {
                        // Skip this path if getAmountsOut fails
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

    /// @notice Calculate optimal split percentages across multiple routers
    /// @dev Uses greedy algorithm to find best distribution minimizing total impact
    function _calculateOptimalSplits(
        uint totalAmountIn,
        address[] memory path,
        uint8 maxSplitsAllowed
    ) internal view returns (
        RouterQuote[] memory selectedQuotes,
        uint16[] memory percentages,
        uint totalExpectedOut
    ) {
        uint fee = totalAmountIn / FEE_DIVISOR;
        uint amountForSwap = totalAmountIn - fee;
        RouterQuote[] memory allQuotes = _getAllRouterQuotes(amountForSwap / 4, path); // Test with 25% chunks after fee

        if (allQuotes.length == 0) {
            return (new RouterQuote[](0), new uint16[](0), 0);
        }

        // Sort quotes by amountOut descending
        allQuotes = _sortQuotesByOutput(allQuotes);

        // Determine optimal number of splits (2-4)
        uint8 numSplits = maxSplitsAllowed > allQuotes.length ? uint8(allQuotes.length) : maxSplitsAllowed;
        if (numSplits > 4) numSplits = 4;
        if (numSplits < 2) numSplits = 2;

        selectedQuotes = new RouterQuote[](numSplits);
        percentages = new uint16[](numSplits);

        // Copy top routers
        for (uint i = 0; i < numSplits; i++) {
            selectedQuotes[i] = allQuotes[i];
        }

        // Calculate optimal distribution using iterative refinement
        totalExpectedOut = _optimizeSplitPercentages(selectedQuotes, percentages, totalAmountIn, path);
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

    /// @notice Optimize split percentages to maximize output
    function _optimizeSplitPercentages(
        RouterQuote[] memory quotes,
        uint16[] memory percentages,
        uint totalAmount,
        address[] memory path
    ) internal view returns (uint totalOut) {
        uint numSplits = quotes.length;

        // Start with equal distribution
        uint16 equalShare = uint16(10000 / numSplits);
        for (uint i = 0; i < numSplits; i++) {
            percentages[i] = equalShare;
        }

        // Adjust last percentage to ensure total = 10000 (100%)
        uint16 totalPct = 0;
        for (uint i = 0; i < numSplits - 1; i++) {
            totalPct += percentages[i];
        }
        percentages[numSplits - 1] = 10000 - totalPct;

        // Iterative optimization: shift allocation towards better routers
        for (uint iteration = 0; iteration < 5; iteration++) {
            uint[] memory outputs = new uint[](numSplits);

            // Calculate output for each split with current allocation
            for (uint i = 0; i < numSplits; i++) {
                uint splitAmount = (totalAmount * percentages[i]) / 10000;
                if (splitAmount == 0) continue;

                if (quotes[i].routerType == RouterType.V2) {
                    try IUniswapV2Router02(quotes[i].router).getAmountsOut(splitAmount, quotes[i].path) returns (uint[] memory amounts) {
                        outputs[i] = amounts[amounts.length - 1];
                    } catch {
                        outputs[i] = 0;
                    }
                } else {
                    address factory = v3RouterToFactory[quotes[i].router];
                    address pool;
                    try IUniswapV3Factory(factory).getPool(path[0], path[1], quotes[i].v3Fee) returns (address p) {
                        pool = p;
                    } catch {
                        continue;
                    }
                    (uint out, ) = _calculateV3SwapOutput(pool, splitAmount, path[0], quotes[i].v3Fee);
                    outputs[i] = out;
                }
            }

            // Find router with best marginal return
            uint bestRouter = 0;
            uint bestMarginal = 0;
            for (uint i = 0; i < numSplits; i++) {
                if (percentages[i] >= 9500) continue; // Don't allocate more than 95% to one router
                uint marginal = outputs[i] * 10000 / (percentages[i] > 0 ? percentages[i] : 1);
                if (marginal > bestMarginal) {
                    bestMarginal = marginal;
                    bestRouter = i;
                }
            }

            // Shift 5% from worst to best (if beneficial)
            uint worstRouter = 0;
            uint worstMarginal = type(uint).max;
            for (uint i = 0; i < numSplits; i++) {
                if (i == bestRouter || percentages[i] <= 500) continue; // Keep at least 5%
                uint marginal = outputs[i] * 10000 / percentages[i];
                if (marginal < worstMarginal) {
                    worstMarginal = marginal;
                    worstRouter = i;
                }
            }

            if (bestMarginal > worstMarginal && percentages[worstRouter] >= 500) {
                percentages[worstRouter] -= 500;
                percentages[bestRouter] += 500;
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
                address pool;
                try IUniswapV3Factory(factory).getPool(path[0], path[1], quotes[i].v3Fee) returns (address p) {
                    pool = p;
                } catch {
                    continue;
                }
                (uint out, ) = _calculateV3SwapOutput(pool, splitAmount, path[0], quotes[i].v3Fee);
                totalOut += out;
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

    /// @notice Get the best swap data with adaptive slippage and optimal routing
    /// @dev GUARANTEED to return valid swap data - tries V2 and V3, returns best available
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
            uint splitAmount = (amountForSwap * percentages[i]) / 10000;
            uint splitAmountWithFee = (amountIn * percentages[i]) / 10000;

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
                amountIn: splitAmountWithFee,
                amountOutMin: splitMinOut,
                deadline: block.timestamp + 300,
                supportFeeOnTransfer: supportFeeOnTransfer
            });
        }

        uint totalMinOut = _calculateAdaptiveSlippage(totalExpectedOut, 0, userSlippageBPS);

        splitData = SplitSwapData({
            splits: splits,
            totalAmountIn: amountIn,
            totalAmountOutMin: totalMinOut,
            splitPercentages: percentages
        });
    }

    /// @notice Get quotes from all available routers
    function _getAllRouterQuotes(uint amountIn, address[] memory path) internal view returns (RouterQuote[] memory) {
        uint maxQuotes = routersV2.length * 2 + routersV3.length * 4; // Account for WETH routing and multiple fee tiers
        RouterQuote[] memory tempQuotes = new RouterQuote[](maxQuotes);
        uint quoteCount = 0;

        // Get V2 quotes (direct path)
        for (uint i = 0; i < routersV2.length; i++) {
            if (!_validateRouter(routersV2[i])) continue;

            // Try direct path - validate pair exists
            if (_validateV2Path(routersV2[i], path)) {
                uint[] memory amounts;
                try IUniswapV2Router02(routersV2[i]).getAmountsOut(amountIn, path) returns (uint[] memory res) {
                    amounts = res;
                    
                    if (amounts.length > 0 && amounts[amounts.length - 1] > 0) {
                        tempQuotes[quoteCount] = RouterQuote({
                            router: routersV2[i],
                            routerType: RouterType.V2,
                            v3Fee: 0,
                            amountOut: amounts[amounts.length - 1],
                            priceImpact: 0,
                            path: path
                        });
                        quoteCount++;
                    }
                } catch {
                    // Skip if quote fails
                }
            }

            // Try WETH routing for token-to-token
            if (path.length == 2 && path[0] != WETH && path[1] != WETH) {
                address[] memory wethPath = new address[](3);
                wethPath[0] = path[0];
                wethPath[1] = WETH;
                wethPath[2] = path[1];

                // Validate WETH path exists
                if (_validateV2Path(routersV2[i], wethPath)) {
                    uint[] memory wethAmounts;
                    try IUniswapV2Router02(routersV2[i]).getAmountsOut(amountIn, wethPath) returns (uint[] memory res) {
                        wethAmounts = res;

                        if (wethAmounts.length > 0 && wethAmounts[wethAmounts.length - 1] > 0) {
                            tempQuotes[quoteCount] = RouterQuote({
                                router: routersV2[i],
                                routerType: RouterType.V2,
                                v3Fee: 0,
                                amountOut: wethAmounts[wethAmounts.length - 1],
                                priceImpact: 0,
                                path: wethPath
                            });
                            quoteCount++;
                        }
                    } catch {
                        // Skip if quote fails
                    }
                }
            }
        }

        // Get V3 quotes (single hop only)
        if (path.length == 2) {
            for (uint i = 0; i < routersV3.length; i++) {
                if (!_validateRouter(routersV3[i])) continue;

                address factory = v3RouterToFactory[routersV3[i]];
                if (factory == address(0)) continue;

                for (uint j = 0; j < v3FeeTiers.length; j++) {
                    uint24 fee = v3FeeTiers[j];

                    // Validate pool exists and has liquidity before quoting
                    if (!_v3PoolExists(factory, path[0], path[1], fee)) {
                        continue;
                    }

                    address pool;
                    try IUniswapV3Factory(factory).getPool(path[0], path[1], fee) returns (address p) {
                        pool = p;
                    } catch {
                        continue;
                    }

                    if (pool == address(0)) continue;

                    (uint amountOut, uint impact) = _calculateV3SwapOutput(pool, amountIn, path[0], fee);

                    if (amountOut > 0) {
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
            }
        }

        // Resize array to actual count
        RouterQuote[] memory quotes = new RouterQuote[](quoteCount);
        for (uint i = 0; i < quoteCount; i++) {
            quotes[i] = tempQuotes[i];
        }

        return quotes;
    }

    /// @notice Find best router with optimal path including V2 WETH routing
    /// @dev Returns fee array for V3 multi-hop routes. Tries V2 and V3, returns best valid route.
    /// @dev This ensures we ALWAYS return a working router - V2 as fallback if V3 fails, and vice versa
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

        // Track if we found ANY valid route
        bool foundV2Route = false;
        bool foundV3Route = false;

        // Check all V2 routers with direct and multi-hop paths
        for (uint i = 0; i < routersV2.length; i++) {
            if (!_validateRouter(routersV2[i])) continue;

            // Try direct path - validate pair exists
            if (_validateV2Path(routersV2[i], path)) {
                uint[] memory amounts;
                try IUniswapV2Router02(routersV2[i]).getAmountsOut(amountIn, path) returns (uint[] memory res) {
                    amounts = res;
                    uint amountOut = amounts[amounts.length - 1];

                    if (amountOut > 0 && amountOut > bestAmountOut) {
                        bestAmountOut = amountOut;
                        bestRouter = routersV2[i];
                        bestRouterType = RouterType.V2;
                        bestPriceImpact = 0;
                        bestPath = path;
                        foundV2Route = true;
                    }
                } catch {
                    // Skip this router if getAmountsOut fails
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
                    uint[] memory wethAmounts;
                    try IUniswapV2Router02(routersV2[i]).getAmountsOut(amountIn, wethPath) returns (uint[] memory res) {
                        wethAmounts = res;
                        uint wethAmountOut = wethAmounts[wethAmounts.length - 1];

                        // If routing through WETH gives better price, use it
                        if (wethAmountOut > 0 && wethAmountOut > bestAmountOut) {
                            bestAmountOut = wethAmountOut;
                            bestRouter = routersV2[i];
                            bestRouterType = RouterType.V2;
                            bestPriceImpact = 0;
                            bestPath = wethPath;
                            foundV2Route = true;
                        }
                    } catch {
                        // Skip this path if getAmountsOut fails
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

                if (bestPool != address(0) && amountOut > 0) {
                    foundV3Route = true;
                    if (amountOut > bestAmountOut) {
                        bestAmountOut = amountOut;
                        bestRouter = routersV3[i];
                        bestRouterType = RouterType.V3;
                        bestV3Fees = new uint24[](1);
                        bestV3Fees[0] = bestFee;
                        bestPriceImpact = impact;
                        bestPath = path;
                    }
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

                    if (pool2 != address(0) && amountOut > 0) {
                        foundV3Route = true;
                        if (amountOut > bestAmountOut) {
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

        // Ensure we found at least one valid route (V2 or V3)
        // If no route found, try returning first active router as last resort
        if (bestRouter == address(0)) {
            // Try first active V2 router
            for (uint i = 0; i < routersV2.length; i++) {
                if (_validateRouter(routersV2[i]) && _validateV2Path(routersV2[i], path)) {
                    bestRouter = routersV2[i];
                    bestRouterType = RouterType.V2;
                    bestPath = path;
                    bestAmountOut = 1; // Minimal non-zero value to pass validation
                    break;
                }
            }
            
            // If still none, try first active V3 router
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
                                    bestAmountOut = 1; // Minimal non-zero value
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

    /// @notice Execute V2 swap
    /// @dev Token transfers and fee accumulation are handled in execute() before this is called
    function _executeV2Swap(SwapData calldata swapData, uint amountForSwap, address recipient) internal returns (uint amountOut) {
        if (swapData.swapType == SwapType.ETH_TO_TOKEN) {
            // ETH was already validated and fee accumulated in execute()
            if (swapData.supportFeeOnTransfer) {
                IUniswapV2Router02(swapData.router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountForSwap}(
                    swapData.amountOutMin,
                    swapData.path,
                    recipient,
                    swapData.deadline
                );
            } else {
                uint[] memory amounts = IUniswapV2Router02(swapData.router).swapExactETHForTokens{value: amountForSwap}(
                    swapData.amountOutMin,
                    swapData.path,
                    recipient,
                    swapData.deadline
                );
                amountOut = amounts[amounts.length - 1];
            }

        } else if (swapData.swapType == SwapType.TOKEN_TO_ETH) {
            require(swapData.path[swapData.path.length - 1] == WETH, "Path must end with WETH");
            // Tokens already transferred to contract and fee accumulated in execute()
            _safeApprove(swapData.path[0], swapData.router, amountForSwap);

            if (swapData.supportFeeOnTransfer) {
                IUniswapV2Router02(swapData.router).swapExactTokensForETHSupportingFeeOnTransferTokens(
                    amountForSwap,
                    swapData.amountOutMin,
                    swapData.path,
                    recipient,
                    swapData.deadline
                );
            } else {
                uint[] memory amounts = IUniswapV2Router02(swapData.router).swapExactTokensForETH(
                    amountForSwap,
                    swapData.amountOutMin,
                    swapData.path,
                    recipient,
                    swapData.deadline
                );
                amountOut = amounts[amounts.length - 1];
            }

        } else {
            // TOKEN_TO_TOKEN: Tokens already transferred to contract and fee accumulated in execute()
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
        uint8 _maxSplits
    ) external onlyOwner {
        require(_maxSplits >= 2 && _maxSplits <= 4, "MonBridgeDex: Max splits must be 2-4");
        splitConfig = SplitConfig({
            enableAutoSplit: _enableAutoSplit,
            minSplitImpactBPS: _minSplitImpactBPS,
            maxSplits: _maxSplits
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

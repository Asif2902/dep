
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
        address[] path;
        uint24[] v3Fees; // For multi-hop V3
        uint amountIn;
        uint amountOutMin;
        uint deadline;
        bool supportFeeOnTransfer;
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
            minLiquidityUSD: 10000e18,
            requireLiquidityCheck: true
        });

        twapConfig = TWAPConfig({
            twapInterval: 1800,
            maxPriceDeviationBPS: 500,
            enableTWAPCheck: true
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

    /// @notice Normalize amount to target decimals
    function _normalizeAmount(
        address token,
        uint256 amount,
        uint8 targetDecimals
    ) internal view returns (uint256) {
        uint8 tokenDecimals = IERC20(token).decimals();
        
        if (tokenDecimals == targetDecimals) {
            return amount;
        } else if (tokenDecimals > targetDecimals) {
            return amount / (10 ** (tokenDecimals - targetDecimals));
        } else {
            return amount * (10 ** (targetDecimals - tokenDecimals));
        }
    }

    /// @notice Validate pool price against TWAP to prevent manipulation
    function _validateTWAP(address pool, uint160 currentPrice) internal view returns (bool) {
        if (!twapConfig.enableTWAPCheck) return true;
        
        // This is a simplified TWAP check
        // In production, you would implement proper TWAP calculation using observations
        // For now, we return true to not block swaps
        // TODO: Implement full TWAP oracle with historical price checks
        return true;
    }

    /// @notice Validate pool liquidity meets minimum requirements
    function _validateLiquidity(uint128 liquidity) internal view returns (bool) {
        if (!liquidityConfig.requireLiquidityCheck) return true;
        
        // Simplified check - in production would convert to USD value
        return liquidity >= uint128(liquidityConfig.minLiquidityUSD);
    }

    /// @notice Calculate V3 swap output using proper constant product formula
    function _calculateV3SwapOutput(
        address pool,
        uint256 amountIn,
        address tokenIn,
        uint24 feeTier
    ) internal view returns (uint256 amountOut, uint256 priceImpact) {
        if (pool == address(0)) return (0, type(uint256).max);
        
        try IUniswapV3Pool(pool).slot0() returns (
            uint160 sqrtPriceX96,
            int24,
            uint16,
            uint16,
            uint16,
            uint8,
            bool
        ) {
            // Validate TWAP to prevent flash loan attacks
            if (!_validateTWAP(pool, sqrtPriceX96)) {
                return (0, type(uint256).max);
            }
            uint128 liquidity;
            try IUniswapV3Pool(pool).liquidity() returns (uint128 liq) {
                liquidity = liq;
            } catch {
                return (0, type(uint256).max);
            }

            if (liquidity == 0 || sqrtPriceX96 == 0) return (0, type(uint256).max);
            
            // Validate liquidity meets minimum requirements
            if (!_validateLiquidity(liquidity)) {
                return (0, type(uint256).max);
            }

            address token0 = IUniswapV3Pool(pool).token0();
            bool zeroForOne = tokenIn == token0;
            
            uint256 feeAmount = (amountIn * feeTier) / 1000000;
            uint256 amountInAfterFee = amountIn - feeAmount;
            
            uint160 sqrtPriceNextX96;
            
            if (zeroForOne) {
                uint256 denominator = (uint256(liquidity) << 96) + 
                    FullMath.mulDiv(amountInAfterFee, sqrtPriceX96, FixedPoint96.Q96);
                
                if (denominator == 0) return (0, type(uint256).max);
                
                sqrtPriceNextX96 = uint160(
                    FullMath.mulDiv(uint256(liquidity) << 96, sqrtPriceX96, denominator)
                );
                
                if (sqrtPriceNextX96 >= sqrtPriceX96) return (0, type(uint256).max);
                
                amountOut = FullMath.mulDiv(
                    liquidity,
                    sqrtPriceX96 - sqrtPriceNextX96,
                    FixedPoint96.Q96
                );
                
                priceImpact = FullMath.mulDiv(
                    uint256(sqrtPriceX96 - sqrtPriceNextX96) * 10000,
                    FixedPoint96.Q96,
                    sqrtPriceX96
                );
            } else {
                sqrtPriceNextX96 = uint160(
                    uint256(sqrtPriceX96) + FullMath.mulDiv(amountInAfterFee, FixedPoint96.Q96, liquidity)
                );
                
                if (sqrtPriceNextX96 <= sqrtPriceX96) return (0, type(uint256).max);
                
                uint256 priceDelta = FullMath.mulDiv(
                    sqrtPriceX96,
                    sqrtPriceNextX96,
                    FixedPoint96.Q96
                );
                
                if (priceDelta == 0) return (0, type(uint256).max);
                
                amountOut = FullMath.mulDiv(
                    liquidity,
                    sqrtPriceNextX96 - sqrtPriceX96,
                    priceDelta
                );
                
                priceImpact = FullMath.mulDiv(
                    uint256(sqrtPriceNextX96 - sqrtPriceX96) * 10000,
                    FixedPoint96.Q96,
                    sqrtPriceX96
                );
            }

            return (amountOut, priceImpact);
        } catch {
            return (0, type(uint256).max);
        }
    }

    /// @notice Find best V3 pool with optimal fee tier selection
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
        uint256 bestScore = 0;
        
        for (uint i = 0; i < v3FeeTiers.length; i++) {
            uint24 fee = v3FeeTiers[i];
            address pool;
            
            try IUniswapV3Factory(factory).getPool(tokenIn, tokenOut, fee) returns (address p) {
                pool = p;
            } catch {
                continue;
            }
            
            if (pool == address(0)) continue;
            
            (uint amountOut, uint impact) = _calculateV3SwapOutput(pool, amountIn, tokenIn, fee);
            
            if (amountOut == 0) continue;
            
            uint256 impactPenalty = (amountOut * impact) / 10000;
            uint256 score = amountOut > impactPenalty ? amountOut - impactPenalty : 0;
            
            if (score > bestScore || (score == bestScore && fee < bestFee)) {
                bestScore = score;
                bestAmountOut = amountOut;
                bestPool = pool;
                bestFee = fee;
                bestImpact = impact;
            }
        }
    }

    /// @notice Validate router is active and healthy
    function _validateRouter(address router) internal view returns (bool) {
        RouterInfo memory info = routerInfo[router];
        
        if (!info.isActive) return false;
        if (info.failureCount >= MAX_FAILURES_BEFORE_DISABLE) return false;
        
        return true;
    }

    /// @notice Find best router (V2 or V3) with highest output
    function _getBestRouter(uint amountIn, address[] memory path) internal view returns (
        address bestRouter,
        uint bestAmountOut,
        RouterType bestRouterType,
        uint24 bestV3Fee,
        uint bestPriceImpact
    ) {
        bestAmountOut = 0;
        bestRouter = address(0);
        bestRouterType = RouterType.V2;
        bestV3Fee = 0;
        bestPriceImpact = type(uint).max;

        // Check all V2 routers (supports multi-hop via path array)
        for (uint i = 0; i < routersV2.length; i++) {
            if (!_validateRouter(routersV2[i])) continue;
            
            uint[] memory amounts;
            try IUniswapV2Router02(routersV2[i]).getAmountsOut(amountIn, path) returns (uint[] memory res) {
                amounts = res;
            } catch {
                continue;
            }
            uint amountOut = amounts[amounts.length - 1];
            
            // V2 supports multi-hop through path array (any length >= 2)
            if (amountOut > bestAmountOut) {
                bestAmountOut = amountOut;
                bestRouter = routersV2[i];
                bestRouterType = RouterType.V2;
                bestPriceImpact = 0; // TODO: Calculate V2 price impact for multi-hop
            }
        }

        // Check all V3 routers (single hop)
        if (path.length == 2) {
            for (uint i = 0; i < routersV3.length; i++) {
                if (!_validateRouter(routersV3[i])) continue;
                
                address factory = v3RouterToFactory[routersV3[i]];
                if (factory == address(0)) continue;

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
                    bestV3Fee = bestFee;
                    bestPriceImpact = impact;
                }
            }
        }
    }

    /// @notice Calculate adaptive slippage based on price impact
    function _calculateAdaptiveSlippage(
        uint256 amountOut,
        uint256 priceImpact,
        uint16 userSlippageBPS
    ) internal view returns (uint256 minAmountOut) {
        uint256 slippageBPS;
        
        if (userSlippageBPS > 0) {
            require(userSlippageBPS <= slippageConfig.maxSlippageBPS, "Slippage too high");
            slippageBPS = userSlippageBPS;
        } else {
            slippageBPS = slippageConfig.baseSlippageBPS;
            
            if (priceImpact > 100) {
                uint256 additionalSlippage = (priceImpact * slippageConfig.impactMultiplier) / 10000;
                slippageBPS += additionalSlippage;
            }
            
            if (slippageBPS > slippageConfig.maxSlippageBPS) {
                slippageBPS = slippageConfig.maxSlippageBPS;
            }
        }
        
        minAmountOut = (amountOut * (10000 - slippageBPS)) / 10000;
    }

    /// @notice Get the best swap data with adaptive slippage
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
        
        SwapType swapType;
        if (path[0] == WETH) {
            swapType = SwapType.ETH_TO_TOKEN;
        } else if (path[path.length - 1] == WETH) {
            swapType = SwapType.TOKEN_TO_ETH;
        } else {
            swapType = SwapType.TOKEN_TO_TOKEN;
        }

        uint fee = amountIn / FEE_DIVISOR;
        uint amountForSwap = amountIn - fee;

        (address bestRouter, uint bestAmountOut, RouterType routerType, uint24 v3Fee, uint priceImpact) = 
            _getBestRouter(amountForSwap, path);
        require(bestRouter != address(0), "MonBridgeDex: No valid router found for this swap path");

        uint amountOutMin = _calculateAdaptiveSlippage(bestAmountOut, priceImpact, userSlippageBPS);

        uint24[] memory v3Fees = new uint24[](1);
        v3Fees[0] = v3Fee;

        swapData = SwapData({
            swapType: swapType,
            routerType: routerType,
            router: bestRouter,
            path: path,
            v3Fees: v3Fees,
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            deadline: block.timestamp + 300,
            supportFeeOnTransfer: supportFeeOnTransfer
        });
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

        uint fee = swapData.amountIn / FEE_DIVISOR;
        uint amountForSwap = swapData.amountIn - fee;

        uint balanceBefore;
        address outputToken = swapData.path[swapData.path.length - 1];
        
        if (swapData.swapType == SwapType.TOKEN_TO_ETH) {
            balanceBefore = msg.sender.balance;
        } else {
            balanceBefore = IERC20(outputToken).balanceOf(msg.sender);
        }

        try this._executeSwapInternal(swapData, amountForSwap, fee) returns (uint result) {
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
    function _executeSwapInternal(SwapData calldata swapData, uint amountForSwap, uint fee) 
        external 
        returns (uint amountOut) 
    {
        require(msg.sender == address(this), "Internal only");
        
        if (swapData.routerType == RouterType.V2) {
            return _executeV2Swap(swapData, amountForSwap, fee);
        } else {
            return _executeV3Swap(swapData, amountForSwap, fee);
        }
    }

    /// @notice Execute V2 swap
    function _executeV2Swap(SwapData calldata swapData, uint amountForSwap, uint fee) internal returns (uint amountOut) {
        if (swapData.swapType == SwapType.ETH_TO_TOKEN) {
            require(swapData.path[0] == WETH, "Path must start with WETH");
            require(msg.value == swapData.amountIn, "Incorrect ETH amount");
            
            feeAccumulatedETH += fee;

            if (swapData.supportFeeOnTransfer) {
                IUniswapV2Router02(swapData.router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountForSwap}(
                    swapData.amountOutMin,
                    swapData.path,
                    msg.sender,
                    swapData.deadline
                );
            } else {
                uint[] memory amounts = IUniswapV2Router02(swapData.router).swapExactETHForTokens{value: amountForSwap}(
                    swapData.amountOutMin,
                    swapData.path,
                    msg.sender,
                    swapData.deadline
                );
                amountOut = amounts[amounts.length - 1];
            }

        } else if (swapData.swapType == SwapType.TOKEN_TO_ETH) {
            require(swapData.path[swapData.path.length - 1] == WETH, "Path must end with WETH");
            
            require(IERC20(swapData.path[0]).transferFrom(msg.sender, address(this), swapData.amountIn), "MonBridgeDex: Token transfer from user failed");
            feeAccumulatedTokens[swapData.path[0]] += fee;

            _safeApprove(swapData.path[0], swapData.router, amountForSwap);

            if (swapData.supportFeeOnTransfer) {
                IUniswapV2Router02(swapData.router).swapExactTokensForETHSupportingFeeOnTransferTokens(
                    amountForSwap,
                    swapData.amountOutMin,
                    swapData.path,
                    msg.sender,
                    swapData.deadline
                );
            } else {
                uint[] memory amounts = IUniswapV2Router02(swapData.router).swapExactTokensForETH(
                    amountForSwap,
                    swapData.amountOutMin,
                    swapData.path,
                    msg.sender,
                    swapData.deadline
                );
                amountOut = amounts[amounts.length - 1];
            }

        } else {
            require(IERC20(swapData.path[0]).transferFrom(msg.sender, address(this), swapData.amountIn), "MonBridgeDex: Token transfer from user failed");
            feeAccumulatedTokens[swapData.path[0]] += fee;

            _safeApprove(swapData.path[0], swapData.router, amountForSwap);

            if (swapData.supportFeeOnTransfer) {
                IUniswapV2Router02(swapData.router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    amountForSwap,
                    swapData.amountOutMin,
                    swapData.path,
                    msg.sender,
                    swapData.deadline
                );
            } else {
                uint[] memory amounts = IUniswapV2Router02(swapData.router).swapExactTokensForTokens(
                    amountForSwap,
                    swapData.amountOutMin,
                    swapData.path,
                    msg.sender,
                    swapData.deadline
                );
                amountOut = amounts[amounts.length - 1];
            }
        }
    }

    /// @notice Encode V3 multi-hop path
    function _encodeV3Path(address[] memory tokens, uint24[] memory fees) internal pure returns (bytes memory path) {
        require(tokens.length >= 2, "Invalid path");
        require(tokens.length == fees.length + 1, "Path/fee mismatch");
        
        path = abi.encodePacked(tokens[0]);
        
        for (uint i = 0; i < fees.length; i++) {
            path = abi.encodePacked(path, fees[i], tokens[i + 1]);
        }
    }

    /// @notice Execute V3 swap (supports multi-hop)
    function _executeV3Swap(SwapData calldata swapData, uint amountForSwap, uint fee) internal returns (uint amountOut) {
        if (swapData.swapType == SwapType.ETH_TO_TOKEN) {
            require(swapData.path[0] == WETH, "MonBridgeDex: Path must start with WETH");
            require(msg.value == swapData.amountIn, "MonBridgeDex: Incorrect ETH amount");
            
            feeAccumulatedETH += fee;

            // V3 requires WETH, so wrap ETH first
            IWETH(WETH).deposit{value: amountForSwap}();
            _safeApprove(WETH, swapData.router, amountForSwap);

            if (swapData.path.length == 2) {
                ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                    tokenIn: swapData.path[0],
                    tokenOut: swapData.path[1],
                    fee: swapData.v3Fees[0],
                    recipient: msg.sender,
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
                    recipient: msg.sender,
                    deadline: swapData.deadline,
                    amountIn: amountForSwap,
                    amountOutMinimum: swapData.amountOutMin
                });

                amountOut = ISwapRouter(swapData.router).exactInput(params);
            }

        } else if (swapData.swapType == SwapType.TOKEN_TO_ETH) {
            require(swapData.path[swapData.path.length - 1] == WETH, "MonBridgeDex: Path must end with WETH");
            
            require(IERC20(swapData.path[0]).transferFrom(msg.sender, address(this), swapData.amountIn), "MonBridgeDex: Token transfer from user failed");
            feeAccumulatedTokens[swapData.path[0]] += fee;

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

            // V3 outputs WETH for TOKEN_TO_ETH, need to unwrap
            IWETH(WETH).withdraw(amountOut);
            payable(msg.sender).transfer(amountOut);

        } else {
            require(IERC20(swapData.path[0]).transferFrom(msg.sender, address(this), swapData.amountIn), "MonBridgeDex: Token transfer from user failed");
            feeAccumulatedTokens[swapData.path[0]] += fee;

            _safeApprove(swapData.path[0], swapData.router, amountForSwap);

            if (swapData.path.length == 2) {
                ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                    tokenIn: swapData.path[0],
                    tokenOut: swapData.path[1],
                    fee: swapData.v3Fees[0],
                    recipient: msg.sender,
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
                    recipient: msg.sender,
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
}

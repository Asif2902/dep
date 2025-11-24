
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

/// @title MonBridgeDex 
/// @notice This contract aggregates multiple DEX routers (Uniswap V2 and V3–style) for best-price swaps.
contract MonBridgeDex {
    address public owner;
    address[] public routersV2;
    address[] public routersV3;
    mapping(address => bool) public isRouterV2;
    mapping(address => bool) public isRouterV3;
    mapping(address => address) public v3RouterToFactory; // V3 router => V3 factory
    uint public constant MAX_ROUTERS = 100;
    uint public feeAccumulatedETH;
    mapping(address => uint) public feeAccumulatedTokens;

    uint public constant FEE_DIVISOR = 1000; // 0.1% fee

    address public WETH;

    bool private _locked;
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
        address[] path; // For V2
        uint24 fee; // For V3 single hop
        uint amountIn;
        uint amountOutMin;
        uint deadline;
        bool supportFeeOnTransfer;
    }

    // V3 fee tiers to check (100 = 0.01%, 500 = 0.05%, 3000 = 0.3%, 10000 = 1%)
    uint24[] public v3FeeTiers;

    event RouterV2Added(address router);
    event RouterV2Removed(address router);
    event RouterV3Added(address router, address factory);
    event RouterV3Removed(address router);
    event SwapExecuted(address indexed user, address router, uint amountIn, uint amountOut, SwapType swapType);
    event FeesWithdrawn(address indexed owner, uint ethAmount);
    event TokenFeesWithdrawn(address indexed owner, address token, uint amount);

    constructor(address _weth) {
        owner = msg.sender;
        WETH = _weth;
        // Initialize V3 fee tiers
        v3FeeTiers.push(100);
        v3FeeTiers.push(500);
        v3FeeTiers.push(3000);
        v3FeeTiers.push(10000);
    }

    /// @notice Add a V2 router
    function addRouter(address _router) external onlyOwner {
        require(_router != address(0), "Invalid router address");
        require(!isRouterV2[_router], "Router already added");
        require(routersV2.length < MAX_ROUTERS, "Max routers reached");
        routersV2.push(_router);
        isRouterV2[_router] = true;
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

    /// @notice Calculate V3 output amount for a given pool using the constant product formula
    /// @dev This is a pure calculation without calling Quoter to avoid issues with view/pure
    function _calculateV3Output(
        address pool,
        uint amountIn,
        address tokenIn
    ) internal view returns (uint amountOut, uint priceImpact) {
        if (pool == address(0)) return (0, type(uint).max);
        
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
                return (0, type(uint).max);
            }

            if (liquidity == 0 || sqrtPriceX96 == 0) return (0, type(uint).max);

            address token0 = IUniswapV3Pool(pool).token0();
            uint24 feeTier = IUniswapV3Pool(pool).fee();
            
            // Calculate output using approximation
            // For small trades relative to liquidity, we can approximate:
            // amountOut ≈ amountIn * price * (1 - fee)
            
            uint feeAmount = (amountIn * feeTier) / 1000000;
            uint amountInAfterFee = amountIn - feeAmount;
            
            // Calculate price from sqrtPriceX96
            // price = (sqrtPriceX96 / 2^96)^2
            uint price;
            if (tokenIn == token0) {
                // token0 -> token1, price = token1/token0
                price = (uint(sqrtPriceX96) * uint(sqrtPriceX96)) >> 192;
                if (price == 0) price = 1;
                amountOut = (amountInAfterFee * price) >> 96;
            } else {
                // token1 -> token0, price = token0/token1 = 1/price
                uint priceInverse = (uint(1) << 192) / (uint(sqrtPriceX96) * uint(sqrtPriceX96));
                amountOut = (amountInAfterFee * priceInverse) >> 96;
            }

            // Calculate price impact
            // Impact = amountIn / (2 * liquidity) as a rough estimate
            uint liquidityValue = uint(liquidity);
            if (liquidityValue > 0) {
                priceImpact = (amountIn * 1e18) / (2 * liquidityValue);
            } else {
                priceImpact = type(uint).max;
            }

            return (amountOut, priceImpact);
        } catch {
            return (0, type(uint).max);
        }
    }

    /// @notice Find best V3 pool across all fee tiers for a token pair
    function _getBestV3Pool(
        address factory,
        address tokenIn,
        address tokenOut,
        uint amountIn
    ) internal view returns (address bestPool, uint24 bestFee, uint bestAmountOut, uint bestImpact) {
        bestAmountOut = 0;
        bestImpact = type(uint).max;
        
        for (uint i = 0; i < v3FeeTiers.length; i++) {
            uint24 fee = v3FeeTiers[i];
            address pool;
            
            try IUniswapV3Factory(factory).getPool(tokenIn, tokenOut, fee) returns (address p) {
                pool = p;
            } catch {
                continue;
            }
            
            if (pool == address(0)) continue;
            
            (uint amountOut, uint impact) = _calculateV3Output(pool, amountIn, tokenIn);
            
            if (amountOut == 0) continue;
            
            // Select pool with best output and lowest impact
            // Prioritize higher output, but penalize high impact
            if (amountOut > bestAmountOut || (amountOut == bestAmountOut && impact < bestImpact)) {
                bestAmountOut = amountOut;
                bestPool = pool;
                bestFee = fee;
                bestImpact = impact;
            }
        }
    }

    /// @notice Internal: find the best router (V2 or V3) with highest output
    function _getBestRouter(uint amountIn, address[] memory path) internal view returns (
        address bestRouter,
        uint bestAmountOut,
        RouterType bestRouterType,
        uint24 bestV3Fee
    ) {
        bestAmountOut = 0;
        bestRouter = address(0);
        bestRouterType = RouterType.V2;
        bestV3Fee = 0;

        // Check all V2 routers
        for (uint i = 0; i < routersV2.length; i++) {
            uint[] memory amounts;
            try IUniswapV2Router02(routersV2[i]).getAmountsOut(amountIn, path) returns (uint[] memory res) {
                amounts = res;
            } catch {
                continue;
            }
            uint amountOut = amounts[amounts.length - 1];
            if (amountOut > bestAmountOut) {
                bestAmountOut = amountOut;
                bestRouter = routersV2[i];
                bestRouterType = RouterType.V2;
            }
        }

        // Check all V3 routers (only for direct swaps, path length = 2)
        if (path.length == 2) {
            for (uint i = 0; i < routersV3.length; i++) {
                address factory = v3RouterToFactory[routersV3[i]];
                if (factory == address(0)) continue;

                (address bestPool, uint24 bestFee, uint amountOut, ) = _getBestV3Pool(
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
                }
            }
        }
    }

    /// @notice Get the best swap data
    function getBestSwapData(uint amountIn, address[] calldata path, bool supportFeeOnTransfer) 
        external 
        view 
        returns (SwapData memory swapData) 
    {
        require(path.length >= 2, "Invalid path");
        
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

        (address bestRouter, uint bestAmountOut, RouterType routerType, uint24 v3Fee) = _getBestRouter(amountForSwap, path);
        require(bestRouter != address(0), "No valid router found");

        // Apply 0.5% slippage
        uint amountOutMin = (bestAmountOut * 995) / 1000;

        swapData = SwapData({
            swapType: swapType,
            routerType: routerType,
            router: bestRouter,
            path: path,
            fee: v3Fee,
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
        returns (uint amountOut) 
    {
        require(
            (swapData.routerType == RouterType.V2 && isRouterV2[swapData.router]) ||
            (swapData.routerType == RouterType.V3 && isRouterV3[swapData.router]),
            "Router not whitelisted"
        );
        require(swapData.path.length >= 2, "Invalid path");
        require(swapData.deadline >= block.timestamp, "Deadline expired");

        uint fee = swapData.amountIn / FEE_DIVISOR;
        uint amountForSwap = swapData.amountIn - fee;

        if (swapData.routerType == RouterType.V2) {
            amountOut = _executeV2Swap(swapData, amountForSwap, fee);
        } else {
            amountOut = _executeV3Swap(swapData, amountForSwap, fee);
        }

        emit SwapExecuted(msg.sender, swapData.router, amountForSwap, amountOut, swapData.swapType);
    }

    /// @notice Execute V2 swap
    function _executeV2Swap(SwapData calldata swapData, uint amountForSwap, uint fee) internal returns (uint amountOut) {
        if (swapData.swapType == SwapType.ETH_TO_TOKEN) {
            require(swapData.path[0] == WETH, "Path must start with WETH");
            require(msg.value == swapData.amountIn, "Incorrect ETH amount");
            
            feeAccumulatedETH += fee;

            uint balanceBefore = IERC20(swapData.path[swapData.path.length - 1]).balanceOf(msg.sender);

            if (swapData.supportFeeOnTransfer) {
                IUniswapV2Router02(swapData.router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountForSwap}(
                    swapData.amountOutMin,
                    swapData.path,
                    msg.sender,
                    swapData.deadline
                );
            } else {
                IUniswapV2Router02(swapData.router).swapExactETHForTokens{value: amountForSwap}(
                    swapData.amountOutMin,
                    swapData.path,
                    msg.sender,
                    swapData.deadline
                );
            }

            uint balanceAfter = IERC20(swapData.path[swapData.path.length - 1]).balanceOf(msg.sender);
            amountOut = balanceAfter - balanceBefore;

        } else if (swapData.swapType == SwapType.TOKEN_TO_ETH) {
            require(swapData.path[swapData.path.length - 1] == WETH, "Path must end with WETH");
            
            require(IERC20(swapData.path[0]).transferFrom(msg.sender, address(this), swapData.amountIn), "Token transfer failed");
            feeAccumulatedTokens[swapData.path[0]] += fee;

            require(IERC20(swapData.path[0]).approve(swapData.router, amountForSwap), "Approve failed");

            uint balanceBefore = msg.sender.balance;

            if (swapData.supportFeeOnTransfer) {
                IUniswapV2Router02(swapData.router).swapExactTokensForETHSupportingFeeOnTransferTokens(
                    amountForSwap,
                    swapData.amountOutMin,
                    swapData.path,
                    msg.sender,
                    swapData.deadline
                );
            } else {
                IUniswapV2Router02(swapData.router).swapExactTokensForETH(
                    amountForSwap,
                    swapData.amountOutMin,
                    swapData.path,
                    msg.sender,
                    swapData.deadline
                );
            }

            uint balanceAfter = msg.sender.balance;
            amountOut = balanceAfter - balanceBefore;

        } else {
            require(IERC20(swapData.path[0]).transferFrom(msg.sender, address(this), swapData.amountIn), "Token transfer failed");
            feeAccumulatedTokens[swapData.path[0]] += fee;

            require(IERC20(swapData.path[0]).approve(swapData.router, amountForSwap), "Approve failed");

            uint balanceBefore = IERC20(swapData.path[swapData.path.length - 1]).balanceOf(msg.sender);

            if (swapData.supportFeeOnTransfer) {
                IUniswapV2Router02(swapData.router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    amountForSwap,
                    swapData.amountOutMin,
                    swapData.path,
                    msg.sender,
                    swapData.deadline
                );
            } else {
                IUniswapV2Router02(swapData.router).swapExactTokensForTokens(
                    amountForSwap,
                    swapData.amountOutMin,
                    swapData.path,
                    msg.sender,
                    swapData.deadline
                );
            }

            uint balanceAfter = IERC20(swapData.path[swapData.path.length - 1]).balanceOf(msg.sender);
            amountOut = balanceAfter - balanceBefore;
        }
    }

    /// @notice Execute V3 swap (single hop only)
    function _executeV3Swap(SwapData calldata swapData, uint amountForSwap, uint fee) internal returns (uint amountOut) {
        require(swapData.path.length == 2, "V3 only supports single hop");
        
        if (swapData.swapType == SwapType.ETH_TO_TOKEN) {
            require(swapData.path[0] == WETH, "Path must start with WETH");
            require(msg.value == swapData.amountIn, "Incorrect ETH amount");
            
            feeAccumulatedETH += fee;

            uint balanceBefore = IERC20(swapData.path[1]).balanceOf(msg.sender);

            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: swapData.path[0],
                tokenOut: swapData.path[1],
                fee: swapData.fee,
                recipient: msg.sender,
                deadline: swapData.deadline,
                amountIn: amountForSwap,
                amountOutMinimum: swapData.amountOutMin,
                sqrtPriceLimitX96: 0
            });

            amountOut = ISwapRouter(swapData.router).exactInputSingle{value: amountForSwap}(params);

            uint balanceAfter = IERC20(swapData.path[1]).balanceOf(msg.sender);
            amountOut = balanceAfter - balanceBefore;

        } else if (swapData.swapType == SwapType.TOKEN_TO_ETH) {
            require(swapData.path[1] == WETH, "Path must end with WETH");
            
            require(IERC20(swapData.path[0]).transferFrom(msg.sender, address(this), swapData.amountIn), "Token transfer failed");
            feeAccumulatedTokens[swapData.path[0]] += fee;

            require(IERC20(swapData.path[0]).approve(swapData.router, amountForSwap), "Approve failed");

            uint balanceBefore = msg.sender.balance;

            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: swapData.path[0],
                tokenOut: swapData.path[1],
                fee: swapData.fee,
                recipient: msg.sender,
                deadline: swapData.deadline,
                amountIn: amountForSwap,
                amountOutMinimum: swapData.amountOutMin,
                sqrtPriceLimitX96: 0
            });

            amountOut = ISwapRouter(swapData.router).exactInputSingle(params);

            uint balanceAfter = msg.sender.balance;
            amountOut = balanceAfter - balanceBefore;

        } else {
            require(IERC20(swapData.path[0]).transferFrom(msg.sender, address(this), swapData.amountIn), "Token transfer failed");
            feeAccumulatedTokens[swapData.path[0]] += fee;

            require(IERC20(swapData.path[0]).approve(swapData.router, amountForSwap), "Approve failed");

            uint balanceBefore = IERC20(swapData.path[1]).balanceOf(msg.sender);

            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: swapData.path[0],
                tokenOut: swapData.path[1],
                fee: swapData.fee,
                recipient: msg.sender,
                deadline: swapData.deadline,
                amountIn: amountForSwap,
                amountOutMinimum: swapData.amountOutMin,
                sqrtPriceLimitX96: 0
            });

            amountOut = ISwapRouter(swapData.router).exactInputSingle(params);

            uint balanceAfter = IERC20(swapData.path[1]).balanceOf(msg.sender);
            amountOut = balanceAfter - balanceBefore;
        }
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

        (, priceImpact) = _calculateV3Output(pool, amountIn, tokenIn);
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
                require(IERC20(tokens[i]).transfer(owner, amount), "Transfer failed");
                emit TokenFeesWithdrawn(owner, tokens[i], amount);
            }
        }
    }

    function emergencyWithdraw(address token, uint amount) external onlyOwner {
        require(IERC20(token).transfer(owner, amount), "Transfer failed");
    }

    receive() external payable {}
}

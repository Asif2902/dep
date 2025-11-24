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

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
}

/// @title MonBridgeDex 
/// @notice This contract aggregates multiple DEX routers (Uniswap V2–style) for best-price swaps.
///         It supports token-to-ETH, ETH-to-token, and token-to-token swaps, takes a 0.1% fee per swap,
///         provides on-chain price impact estimation, and allows the owner to withdraw accumulated fees.
contract MonBridgeDex  {
    address public owner;
    address[] public routers;
    uint public constant MAX_ROUTERS = 100;
    uint public feeAccumulatedETH;
    mapping(address => uint) public feeAccumulatedTokens; // token => fee amount

    // Fee divisor: fee = amount / FEE_DIVISOR (0.1% fee)
    uint public constant FEE_DIVISOR = 1000;

    // WETH address used for ETH/token swaps. Set via setWETH().
    address public WETH;

    // Simple reentrancy guard.
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

    event RouterAdded(address router);
    event RouterRemoved(address router);
    event SwapExecuted(address indexed user, address router, uint amountIn, uint amountOut);
    event FeesWithdrawn(address indexed owner, uint ethAmount);
    event TokenFeesWithdrawn(address indexed owner, address token, uint amount);

    constructor(address _weth) {
        owner = msg.sender;
        WETH = _weth;
    }

    /// @notice Add a new DEX router address (max 10).
    function addRouter(address _router) external onlyOwner {
        require(routers.length < MAX_ROUTERS, "Max routers added");
        routers.push(_router);
        emit RouterAdded(_router);
    }

    /// @notice Remove an existing DEX router.
    function removeRouter(address _router) external onlyOwner {
        for (uint i = 0; i < routers.length; i++) {
            if (routers[i] == _router) {
                routers[i] = routers[routers.length - 1];
                routers.pop();
                emit RouterRemoved(_router);
                break;
            }
        }
    }

    /// @notice Get the list of added router addresses.
    function getRouters() external view returns (address[] memory) {
        return routers;
    }

    /// @notice Internal: loop over routers to find the best amountOut for a given swap.
    /// @param amountIn The input amount (after fee deduction).
    /// @param path The swap path (e.g. [WETH, token] for ETH→token).
    /// @return bestRouter The router with the highest quoted output.
    /// @return bestAmountOut The highest output amount among routers.
    function _getBestRouter(uint amountIn, address[] memory path) internal view returns (address bestRouter, uint bestAmountOut) {
        bestAmountOut = 0;
        bestRouter = address(0);
        for (uint i = 0; i < routers.length; i++) {
            uint[] memory amounts;
            // Use try/catch to skip routers that revert (for example, due to an invalid path).
            try IUniswapV2Router02(routers[i]).getAmountsOut(amountIn, path) returns (uint[] memory res) {
                amounts = res;
            } catch {
                continue;
            }
            uint amountOut = amounts[amounts.length - 1];
            if (amountOut > bestAmountOut) {
                bestAmountOut = amountOut;
                bestRouter = routers[i];
            }
        }
    }

    /// @notice External view function to fetch the best router and quote for a given swap.
    /// @param amountIn The input amount.
    /// @param path The swap path.
    /// @return routerAddress The router offering the best quote.
    /// @return amountOut The quoted output amount.
    function getBestSwap(uint amountIn, address[] calldata path) external view returns (address routerAddress, uint amountOut) {
        return _getBestRouter(amountIn, path);
    }

    /// @notice Swap ETH for tokens using the best router.
    /// @param amountOutMin The minimum acceptable output amount.
    /// @param path The swap path; the first element must be WETH.
    /// @param deadline Unix timestamp after which the swap is invalid.
    /// @return amounts The amounts received from the router swap.
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, uint deadline)
        external
        payable
        nonReentrant
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, "Path must start with WETH");
        // Calculate fee and amount used for swap.
        uint fee = msg.value / FEE_DIVISOR;
        uint amountForSwap = msg.value - fee;
        feeAccumulatedETH += fee;

        (address bestRouter, uint bestAmountOut) = _getBestRouter(amountForSwap, path);
        require(bestRouter != address(0), "No valid router found");
        require(bestAmountOut >= amountOutMin, "Insufficient output amount");

        amounts = IUniswapV2Router02(bestRouter).swapExactETHForTokens{value: amountForSwap}(
            amountOutMin,
            path,
            msg.sender,
            deadline
        );
        emit SwapExecuted(msg.sender, bestRouter, amountForSwap, amounts[amounts.length - 1]);
    }

    /// @notice Swap tokens for ETH using the best router.
    /// @param amountIn The exact amount of input tokens.
    /// @param amountOutMin The minimum acceptable ETH output.
    /// @param path The swap path; the last element must be WETH.
    /// @param deadline Unix timestamp after which the swap is invalid.
    /// @return amounts The amounts received from the router swap.
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, uint deadline)
        external
        nonReentrant
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, "Path must end with WETH");
        // Transfer tokens from user.
        require(IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn), "Token transfer failed");
        // Calculate fee.
        uint fee = amountIn / FEE_DIVISOR;
        uint amountForSwap = amountIn - fee;
        feeAccumulatedTokens[path[0]] += fee;

        (address bestRouter, uint bestAmountOut) = _getBestRouter(amountForSwap, path);
        require(bestRouter != address(0), "No valid router found");
        require(bestAmountOut >= amountOutMin, "Insufficient output amount");

        // Approve the best router.
        require(IERC20(path[0]).approve(bestRouter, amountForSwap), "Approve failed");
        amounts = IUniswapV2Router02(bestRouter).swapExactTokensForETH(
            amountForSwap,
            amountOutMin,
            path,
            msg.sender,
            deadline
        );
        emit SwapExecuted(msg.sender, bestRouter, amountForSwap, amounts[amounts.length - 1]);
    }

    /// @notice Swap tokens for tokens using the best router.
    /// @param amountIn The exact amount of input tokens.
    /// @param amountOutMin The minimum acceptable output tokens.
    /// @param path The swap path.
    /// @param deadline Unix timestamp after which the swap is invalid.
    /// @return amounts The amounts received from the router swap.
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, uint deadline)
        external
        nonReentrant
        returns (uint[] memory amounts)
    {
        // Transfer tokens from user.
        require(IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn), "Token transfer failed");
        uint fee = amountIn / FEE_DIVISOR;
        uint amountForSwap = amountIn - fee;
        feeAccumulatedTokens[path[0]] += fee;

        (address bestRouter, uint bestAmountOut) = _getBestRouter(amountForSwap, path);
        require(bestRouter != address(0), "No valid router found");
        require(bestAmountOut >= amountOutMin, "Insufficient output amount");

        require(IERC20(path[0]).approve(bestRouter, amountForSwap), "Approve failed");
        amounts = IUniswapV2Router02(bestRouter).swapExactTokensForTokens(
            amountForSwap,
            amountOutMin,
            path,
            msg.sender,
            deadline
        );
        emit SwapExecuted(msg.sender, bestRouter, amountForSwap, amounts[amounts.length - 1]);
    }

    /// @notice Estimate price impact for a given swap on a specified router.
    /// @dev The function compares the “ideal” output (based on reserves ratio) with the router’s quoted output.
    /// @param router The DEX router to check.
    /// @param tokenIn The input token.
    /// @param tokenOut The output token.
    /// @param amountIn The input amount.
    /// @return priceImpact The price impact scaled by 1e18 (i.e. 1e18 means 100% impact).
    function getPriceImpact(address router, address tokenIn, address tokenOut, uint amountIn) external view returns (uint priceImpact) {
        // Get the pair from the router's factory.
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
        // Compute ideal output assuming no slippage: (amountIn * reserveOut) / reserveIn.
        uint idealOutput = (amountIn * reserveOut) / reserveIn;
        // Get actual output from router.
        address[] memory path = getPath(tokenIn, tokenOut);
        uint[] memory amounts = IUniswapV2Router02(router).getAmountsOut(amountIn, path);
        uint actualOutput = amounts[amounts.length - 1];
        if (idealOutput > actualOutput) {
            priceImpact = ((idealOutput - actualOutput) * 1e18) / idealOutput;
        } else {
            priceImpact = 0;
        }
    }

    /// @notice Helper: returns a two-element path array.
    function getPath(address tokenIn, address tokenOut) public pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        return path;
    }

    /// @notice Owner-only function to withdraw accumulated ETH fees.
    function withdrawFeesETH() external onlyOwner {
        uint amount = feeAccumulatedETH;
        require(amount > 0, "No ETH fees");
        feeAccumulatedETH = 0;
        payable(owner).transfer(amount);
        emit FeesWithdrawn(owner, amount);
    }

    /// @notice Owner-only function to withdraw accumulated token fees.
    /// @param token The token address for which fees were collected.
    function withdrawFeesToken(address token) external onlyOwner {
        uint amount = feeAccumulatedTokens[token];
        require(amount > 0, "No token fees");
        feeAccumulatedTokens[token] = 0;
        require(IERC20(token).transfer(owner, amount), "Transfer failed");
        emit TokenFeesWithdrawn(owner, token, amount);
    }

    // Allow the contract to receive ETH.
    receive() external payable {}
}
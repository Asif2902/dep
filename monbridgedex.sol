
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
/// @notice This contract aggregates multiple DEX routers (Uniswap V2–style) for best-price swaps.
///         It supports token-to-ETH, ETH-to-token, and token-to-token swaps with fee-on-transfer tokens,
///         takes a 0.1% fee per swap, and allows the owner to withdraw accumulated fees.
contract MonBridgeDex {
    address public owner;
    address[] public routers;
    mapping(address => bool) public isRouter;
    uint public constant MAX_ROUTERS = 100;
    uint public feeAccumulatedETH;
    mapping(address => uint) public feeAccumulatedTokens; // token => fee amount

    // Fee divisor: fee = amount / FEE_DIVISOR (0.1% fee)
    uint public constant FEE_DIVISOR = 1000;

    // WETH address used for ETH/token swaps.
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

    enum SwapType {
        ETH_TO_TOKEN,
        TOKEN_TO_ETH,
        TOKEN_TO_TOKEN
    }

    struct SwapData {
        SwapType swapType;
        address router;
        address[] path;
        uint amountIn;
        uint amountOutMin;
        uint deadline;
        bool supportFeeOnTransfer;
    }

    event RouterAdded(address router);
    event RouterRemoved(address router);
    event SwapExecuted(address indexed user, address router, uint amountIn, uint amountOut, SwapType swapType);
    event FeesWithdrawn(address indexed owner, uint ethAmount);
    event TokenFeesWithdrawn(address indexed owner, address token, uint amount);

    constructor(address _weth) {
        owner = msg.sender;
        WETH = _weth;
    }

    /// @notice Add a new DEX router address (max 100).
    function addRouter(address _router) external onlyOwner {
        require(_router != address(0), "Invalid router address");
        require(!isRouter[_router], "Router already added");
        require(routers.length < MAX_ROUTERS, "Max routers reached");
        routers.push(_router);
        isRouter[_router] = true;
        emit RouterAdded(_router);
    }

    /// @notice Add multiple routers at once.
    function addRouters(address[] calldata _routers) external onlyOwner {
        for (uint i = 0; i < _routers.length; i++) {
            require(_routers[i] != address(0), "Invalid router address");
            require(!isRouter[_routers[i]], "Router already added");
            require(routers.length < MAX_ROUTERS, "Max routers reached");
            routers.push(_routers[i]);
            isRouter[_routers[i]] = true;
            emit RouterAdded(_routers[i]);
        }
    }

    /// @notice Remove an existing DEX router.
    function removeRouter(address _router) external onlyOwner {
        require(isRouter[_router], "Router not found");
        for (uint i = 0; i < routers.length; i++) {
            if (routers[i] == _router) {
                routers[i] = routers[routers.length - 1];
                routers.pop();
                isRouter[_router] = false;
                emit RouterRemoved(_router);
                break;
            }
        }
    }

    /// @notice Remove multiple routers at once.
    function removeRouters(address[] calldata _routers) external onlyOwner {
        for (uint i = 0; i < _routers.length; i++) {
            if (isRouter[_routers[i]]) {
                for (uint j = 0; j < routers.length; j++) {
                    if (routers[j] == _routers[i]) {
                        routers[j] = routers[routers.length - 1];
                        routers.pop();
                        isRouter[_routers[i]] = false;
                        emit RouterRemoved(_routers[i]);
                        break;
                    }
                }
            }
        }
    }

    /// @notice Get the list of added router addresses.
    function getRouters() external view returns (address[] memory) {
        return routers;
    }

    /// @notice Internal: loop over routers to find the best amountOut for a given swap.
    /// @param amountIn The input amount (after fee deduction).
    /// @param path The swap path.
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

    /// @notice Get the best router and swap data for execution.
    /// @param amountIn The input amount (before fee).
    /// @param path The swap path.
    /// @param supportFeeOnTransfer Whether to use fee-on-transfer functions.
    /// @return swapData Complete swap data ready for execution.
    function getBestSwapData(uint amountIn, address[] calldata path, bool supportFeeOnTransfer) 
        external 
        view 
        returns (SwapData memory swapData) 
    {
        require(path.length >= 2, "Invalid path");
        
        // Determine swap type
        SwapType swapType;
        if (path[0] == WETH) {
            swapType = SwapType.ETH_TO_TOKEN;
        } else if (path[path.length - 1] == WETH) {
            swapType = SwapType.TOKEN_TO_ETH;
        } else {
            swapType = SwapType.TOKEN_TO_TOKEN;
        }

        // Calculate amount after fee
        uint fee = amountIn / FEE_DIVISOR;
        uint amountForSwap = amountIn - fee;

        // Find best router
        (address bestRouter, uint bestAmountOut) = _getBestRouter(amountForSwap, path);
        require(bestRouter != address(0), "No valid router found");

        // Apply slippage (0.5% default)
        uint amountOutMin = (bestAmountOut * 995) / 1000;

        swapData = SwapData({
            swapType: swapType,
            router: bestRouter,
            path: path,
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            deadline: block.timestamp + 300, // 5 minutes
            supportFeeOnTransfer: supportFeeOnTransfer
        });
    }

    /// @notice Execute a swap with the provided swap data.
    /// @param swapData The swap parameters generated by getBestSwapData.
    /// @return amountOut The actual output amount received.
    function execute(SwapData calldata swapData) 
        external 
        payable 
        nonReentrant 
        returns (uint amountOut) 
    {
        require(isRouter[swapData.router], "Router not whitelisted");
        require(swapData.path.length >= 2, "Invalid path");
        require(swapData.deadline >= block.timestamp, "Deadline expired");

        // Calculate fee
        uint fee = swapData.amountIn / FEE_DIVISOR;
        uint amountForSwap = swapData.amountIn - fee;

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

        } else { // TOKEN_TO_TOKEN
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

        emit SwapExecuted(msg.sender, swapData.router, amountForSwap, amountOut, swapData.swapType);
    }

    /// @notice Estimate price impact for a given swap on a specified router.
    /// @param router The DEX router to check.
    /// @param tokenIn The input token.
    /// @param tokenOut The output token.
    /// @param amountIn The input amount.
    /// @return priceImpact The price impact scaled by 1e18 (i.e. 1e18 means 100% impact).
    function getPriceImpact(address router, address tokenIn, address tokenOut, uint amountIn) external view returns (uint priceImpact) {
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

    /// @notice Withdraw all accumulated fees for multiple tokens at once.
    /// @param tokens Array of token addresses to withdraw fees for.
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

    /// @notice Emergency function to withdraw any token stuck in the contract.
    /// @param token The token address to withdraw.
    /// @param amount The amount to withdraw.
    function emergencyWithdraw(address token, uint amount) external onlyOwner {
        require(IERC20(token).transfer(owner, amount), "Transfer failed");
    }

    // Allow the contract to receive ETH.
    receive() external payable {}
}

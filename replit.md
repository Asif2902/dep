# MonBridgeDex - DEX Aggregator

## Overview

MonBridgeDex is a production-grade decentralized exchange (DEX) aggregator deployed on the Monad blockchain (Chain ID: 143). The platform aggregates liquidity from Uniswap V2 and V3 compatible protocols to find optimal trading routes with zero-failure routing capabilities. The smart contract enables users to execute token swaps across multiple DEX protocols while minimizing slippage and maximizing returns through intelligent route discovery.

## Recent Changes

**November 25, 2025 (Latest)**: Fixed critical V3 price calculation causing CALL_EXCEPTION
- **CRITICAL FIX**: Rewrote V3 swap output calculation in `_calculateV3SwapOutput` to handle decimal mismatches
  - **Root Cause**: Direct squaring of `sqrtPriceX96` caused overflow; decimal differences truncated output to zero
  - **Old (Broken)**: `priceNumerator = sqrtPriceX96 * sqrtPriceX96` → arithmetic overflow for many pools
  - **New (Fixed)**: Two-step `FullMath.mulDiv` using `FixedPoint96.Q96` constant to avoid overflow
  - **Result**: V3 quotes now return positive amounts for USDC/WETH and all token pairs
- **Fixed**: Removed double decimal adjustment (V3 price already encodes token decimals)
- **Fixed**: Removed hardcoded 3% slippage, now uses configurable `baseSlippageBPS`
- **Added**: Fallback scoring in `_getBestV3Pool` to prevent zero-score filtering
- **Improved**: Error messages in routing functions for better debugging
- **Impact**: CALL_EXCEPTION resolved - getBestSwapData now successfully returns V3 routes
- Contract compiles successfully at 37,422 bytes (within Monad's 128KB limit)

**November 25, 2025 (Earlier)**: Fixed critical routing and validation issues
- Added proper V2 pair validation with token sorting to match Uniswap V2 factory storage
- Implemented V3 pool validation checking pool existence and liquidity
- Fixed V2/V3 router interference where adding V3 routers would break V2 routing
- Added helper functions for verification: `getRoutersV2Count()`, `getRoutersV3Count()`, `getV3FeeTiers()`, `feePercent()`
- Multi-hop paths now properly validated for both V2 and V3 routers

## User Preferences

Preferred communication style: Simple, everyday language.

**Rules**:
1. Monad supports 128KB contract size limit (not 24KB)
2. No oversimplification of contract logic
3. Avoid using Quoter02 or any Quoter that cannot be used in pure functions like `getBestSwapData`
4. Use only libraries and methods compatible with pure/view functions for routing calculations

## System Architecture

### Smart Contract Design

**Core Contract**: MonBridgeDex.sol
- **Language**: Solidity 0.8.20
- **Compilation**: Via-IR optimization enabled with 200 runs for complex contract optimization
- **Design Pattern**: Aggregator pattern that interfaces with multiple DEX protocols
- **Access Control**: Owner-based permissions for administrative functions (router management, fee configuration)

**Key Architectural Decisions**:
1. **Multi-Protocol Support**: Supports both Uniswap V2 and V3 protocols to maximize liquidity access
   - V2 routers use traditional AMM pricing
   - V3 routers utilize concentrated liquidity with multiple fee tiers (500, 3000, 10000 bps)
2. **Router Registry**: Maintains separate lists of V2 and V3 routers for flexible liquidity sourcing
3. **Fee Structure**: Implements a configurable fee system (in basis points) for revenue generation
4. **WETH Integration**: Native ETH/WETH conversion support for seamless native token trading

### Deployment Architecture

**Network Configuration**:
- **Blockchain**: Monad Mainnet (Chain ID 143)
- **RPC Endpoint**: https://rpc.monad.xyz
- **Contract Address**: 0x7Db8Be2395E0a85269333CA99312c409A5B409f9
- **WETH Address**: 0x3bd359c1119da7da1d913d1c4d2b7c461115433a
- **Deployment Tool**: Hardhat with custom deployment scripts

**Deployment Choices**:
- Uses environment-based configuration for private keys and RPC URLs
- Automatic deployment info persistence (deployment-info.json, public/deployment.json)
- Verification scripts included for post-deployment validation

### Frontend Architecture

**Technology Stack**:
- **Framework**: Vanilla HTML/CSS/JavaScript (static web application)
- **Web3 Library**: Ethers.js for blockchain interaction
- **Deployment Strategy**: Static hosting via `/public` directory

**Interface Features**:
1. Wallet connection with MetaMask integration
2. Router management (add/remove V2 and V3 routers)
3. Trade execution interface with route discovery
4. Administrative controls for contract management
5. Auto-loading of contract configuration from deployment.json

**Design Rationale**: Simple static approach chosen for minimal dependencies and easy deployment without requiring a build process or server infrastructure.

### Development Environment

**Build System**: Hardhat
- Custom network configuration for Monad
- Hardhat Toolbox for comprehensive development features
- Artifact caching for faster recompilation

**Project Structure**:
```
contracts/     - Smart contract source code
scripts/       - Deployment and verification scripts
test/          - Test suite (structure in place)
artifacts/     - Compiled contract artifacts
public/        - Frontend static files
cache/         - Build cache
```

## External Dependencies

### Blockchain Dependencies

1. **Uniswap V2 Protocol**
   - Package: `@uniswap/v2-core`, `@uniswap/v2-periphery`
   - Purpose: V2 router interfaces and factory contracts for AMM-based swaps
   - Integration: Contract interfaces for querying pairs and executing swaps

2. **Uniswap V3 Protocol**
   - Package: `@uniswap/v3-core`, `@uniswap/v3-periphery`
   - Purpose: V3 router interfaces with concentrated liquidity support
   - Integration: Pool queries, fee tier management, and advanced swap routing

3. **OpenZeppelin Contracts**
   - Package: `@openzeppelin/contracts` v5.4.0
   - Purpose: Secure, audited contract utilities (likely for ownership, reentrancy guards, safe math)
   - Rationale: Industry-standard security patterns

### Development Dependencies

1. **Hardhat Framework**
   - Package: `hardhat` v2.27.0
   - Purpose: Ethereum development environment for compilation, testing, and deployment
   - Features: Built-in console, network management, task runner

2. **Hardhat Toolbox**
   - Package: `@nomicfoundation/hardhat-toolbox` v4.0.0
   - Purpose: Bundle of essential Hardhat plugins
   - Includes: Ethers.js, testing utilities, gas reporting

### Network Infrastructure

1. **Monad RPC**
   - URL: https://rpc.monad.xyz
   - Purpose: Primary blockchain connection for contract deployment and interaction
   - Chain ID: 143

2. **WETH Contract**
   - Address: 0x3bd359c1119da7da1d913d1c4d2b7c461115433a
   - Purpose: Wrapped Ether implementation on Monad for ERC-20 compatibility

### Frontend Integration

1. **Ethers.js**
   - Source: CDN (https://monbridgedex.xyz/ethers.js)
   - Purpose: Web3 provider and contract interaction library
   - Usage: Wallet connection, transaction signing, contract calls

**Note**: The system is designed to work with various Uniswap-compatible DEX routers that may be added post-deployment. Router addresses are configurable through the contract's administrative interface.
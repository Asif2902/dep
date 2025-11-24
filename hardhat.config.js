require("@nomicfoundation/hardhat-toolbox");

// Load environment variables
const PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY || "";
const MONAD_RPC_URL = process.env.MONAD_RPC_URL || "https://rpc.monad.xyz";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  networks: {
    hardhat: {
      chainId: 1337
    },
    monad: {
      url: MONAD_RPC_URL,
      chainId: 10143, // Monad testnet chain ID
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      timeout: 60000,
      gasPrice: "auto"
    }
  },
  defaultNetwork: "hardhat"
};

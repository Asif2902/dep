require("@nomicfoundation/hardhat-toolbox");

// Load environment variables
const PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY || "";
const MONAD_RPC_URL = "https://rpc.monad.xyz";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true,
      // Metadata settings to reduce bytecode size
      metadata: {
        bytecodeHash: "none"
      }
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
      chainId: 1337,
      allowUnlimitedContractSize: true, // Allow large contracts in local testing
      gas: 30000000, // Increase gas limit for deployment
      blockGasLimit: 30000000
    },
    monad: {
      url: MONAD_RPC_URL,
      chainId: 143, // Monad mainnet chain ID
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      timeout: 120000, // Increase timeout to 2 minutes
      gas: 30000000, // Set high gas limit for large contract deployment
      gasPrice: "auto",
      allowUnlimitedContractSize: false // Monad supports up to 128KB, keep this false but set high gas
    }
  },
  defaultNetwork: "hardhat"
};

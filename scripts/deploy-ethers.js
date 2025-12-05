const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("=".repeat(60));
    console.log("MonBridgeDex Standalone Ethers.js Deployment");
    console.log("=".repeat(60));
    console.log();

    const privateKey = process.env.DEPLOYER_PRIVATE_KEY;
    if (!privateKey) {
        console.log("Error: DEPLOYER_PRIVATE_KEY not found in environment variables");
        console.log("Please set DEPLOYER_PRIVATE_KEY in Replit Secrets (Tools > Secrets)");
        process.exit(1);
    }

    const MONAD_RPC_URL = "https://rpc.monad.xyz";
    const CHAIN_ID = 143;
    const WETH_ADDRESS = "0x3bd359c1119da7da1d913d1c4d2b7c461115433a";
    const USDC_ADDRESS = "0x754704Bc059F8C67012fEd69BC8A327a5aafb603";

    console.log("Network: Monad");
    console.log("RPC URL:", MONAD_RPC_URL);
    console.log("Chain ID:", CHAIN_ID);
    console.log();

    const provider = new ethers.JsonRpcProvider(MONAD_RPC_URL, {
        chainId: CHAIN_ID,
        name: "monad"
    });

    const wallet = new ethers.Wallet(privateKey, provider);
    console.log("Deployer Address:", wallet.address);

    const balance = await provider.getBalance(wallet.address);
    console.log("Account Balance:", ethers.formatEther(balance), "MON");
    console.log();

    if (balance === 0n) {
        console.log("Error: Account has no balance. Please fund your account with MON.");
        process.exit(1);
    }

    const artifactPath = path.join(__dirname, "../artifacts/contracts/MonBridgeDex.sol/MonBridgeDex.json");
    
    if (!fs.existsSync(artifactPath)) {
        console.log("Error: Contract artifact not found. Please run 'npx hardhat compile' first.");
        process.exit(1);
    }

    const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
    const bytecode = artifact.bytecode;
    const abi = artifact.abi;

    const bytecodeSize = (bytecode.length - 2) / 2;
    console.log("Contract bytecode size:", bytecodeSize, "bytes");
    console.log("Size in KB:", (bytecodeSize / 1024).toFixed(2), "KB");
    
    if (bytecodeSize > 128 * 1024) {
        console.log("Error: Contract exceeds Monad's 128KB limit");
        process.exit(1);
    }
    console.log("Contract size within Monad's 128KB limit");
    console.log();

    console.log("=".repeat(60));
    console.log("Deploying Contract...");
    console.log("=".repeat(60));
    console.log();

    const factory = new ethers.ContractFactory(abi, bytecode, wallet);

    console.log("Constructor Arguments:");
    console.log("  WETH:", WETH_ADDRESS);
    console.log("  USDC:", USDC_ADDRESS);
    console.log();

    try {
        console.log("Estimating gas...");
        const deploymentData = factory.interface.encodeDeploy([WETH_ADDRESS, USDC_ADDRESS]);
        const fullBytecode = bytecode + deploymentData.slice(2);
        
        let gasEstimate;
        try {
            gasEstimate = await provider.estimateGas({
                data: fullBytecode,
                from: wallet.address
            });
            console.log("Estimated gas:", gasEstimate.toString());
        } catch (e) {
            console.log("Gas estimation failed, using high gas limit...");
            gasEstimate = 30000000n;
        }

        const feeData = await provider.getFeeData();
        console.log("Gas price:", ethers.formatUnits(feeData.gasPrice || 0n, "gwei"), "gwei");
        
        const gasLimit = gasEstimate * 130n / 100n;
        console.log("Gas limit (with 30% buffer):", gasLimit.toString());
        console.log();

        console.log("Sending deployment transaction...");
        const contract = await factory.deploy(WETH_ADDRESS, USDC_ADDRESS, {
            gasLimit: gasLimit
        });

        console.log("Transaction hash:", contract.deploymentTransaction()?.hash);
        console.log();
        console.log("Waiting for confirmation (this may take a few minutes)...");
        
        await contract.waitForDeployment();
        
        const contractAddress = await contract.getAddress();
        
        console.log();
        console.log("=".repeat(60));
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("=".repeat(60));
        console.log();
        console.log("Contract Address:", contractAddress);
        console.log();

        const blockNumber = await provider.getBlockNumber();
        const deploymentInfo = {
            network: "monad",
            chainId: CHAIN_ID,
            contractAddress: contractAddress,
            deployer: wallet.address,
            deployedAt: new Date().toISOString(),
            blockNumber: blockNumber,
            txHash: contract.deploymentTransaction()?.hash,
            constructorArgs: {
                WETH: WETH_ADDRESS,
                USDC: USDC_ADDRESS
            }
        };

        fs.writeFileSync(
            "deployment-info.json",
            JSON.stringify(deploymentInfo, null, 2)
        );
        console.log("Deployment info saved to deployment-info.json");

        fs.writeFileSync(
            "public/deployment.json",
            JSON.stringify({
                contractAddress: contractAddress,
                network: "monad",
                chainId: CHAIN_ID,
                deployedAt: deploymentInfo.deployedAt
            }, null, 2)
        );
        console.log("Frontend config saved to public/deployment.json");

        console.log();
        console.log("=".repeat(60));
        console.log("Next Steps:");
        console.log("=".repeat(60));
        console.log("1. Add Uniswap V2 routers using addRouter()");
        console.log("2. Add Uniswap V3 routers using addV3Router()");
        console.log("3. Add intermediate tokens for multi-hop routing");
        console.log("4. Use the HTML interface to manage and test swaps");
        console.log();

    } catch (error) {
        console.log();
        console.log("=".repeat(60));
        console.log("DEPLOYMENT FAILED");
        console.log("=".repeat(60));
        console.log();
        
        if (error.code === "INSUFFICIENT_FUNDS") {
            console.log("Error: Insufficient funds for deployment");
            console.log("Please add more MON to your wallet:", wallet.address);
        } else if (error.code === "NONCE_EXPIRED") {
            console.log("Error: Nonce issue. There may be a pending transaction.");
            console.log("Please wait for pending transactions to complete and try again.");
        } else if (error.message?.includes("timeout")) {
            console.log("Error: Transaction timed out");
            console.log("The network may be congested. Try again later.");
        } else {
            console.log("Error details:", error.message || error);
            if (error.transaction) {
                console.log("Transaction:", error.transaction);
            }
            if (error.receipt) {
                console.log("Receipt:", error.receipt);
            }
        }
        
        process.exit(1);
    }
}

main()
    .then(() => {
        console.log("Deployment script completed.");
        process.exit(0);
    })
    .catch((error) => {
        console.error("Unexpected error:", error);
        process.exit(1);
    });

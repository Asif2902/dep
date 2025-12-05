const hre = require("hardhat");

async function main() {
  // Check if private key is available
  const privateKey = process.env.DEPLOYER_PRIVATE_KEY;
  if (!privateKey) {
    console.log("❌ Error: DEPLOYER_PRIVATE_KEY not found in environment variables");
    console.log("📝 Please set DEPLOYER_PRIVATE_KEY in Replit Secrets (Tools > Secrets)");
    process.exit(1);
  }

  console.log("🚀 Deploying MonBridgeDex to Monad...\n");

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("📝 Deploying with account:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", hre.ethers.formatEther(balance), "MON\n");

  // Deploy contract
  console.log("⏳ Deploying MonBridgeDex contract...");
  const MonBridgeDex = await hre.ethers.getContractFactory("MonBridgeDex");
  
  // Check compiled bytecode size
  const bytecode = MonBridgeDex.bytecode;
  const bytecodeSize = (bytecode.length - 2) / 2; // Remove '0x' and divide by 2
  console.log("📊 Contract bytecode size:", bytecodeSize, "bytes");
  console.log("📊 Size in KB:", (bytecodeSize / 1024).toFixed(2), "KB");
  
  if (bytecodeSize > 128 * 1024) {
    console.log("❌ Error: Contract exceeds 128KB limit");
    process.exit(1);
  }
  
  // WETH and USDC addresses on Monad
  const WETH_ADDRESS = "0x3bd359c1119da7da1d913d1c4d2b7c461115433a";
  const USDC_ADDRESS = "0x754704Bc059F8C67012fEd69BC8A327a5aafb603"; // Set to actual USDC address or address(0) if not using
  
  console.log("🚀 Deploying with high gas limit to accommodate large contract...");
  const monBridgeDex = await MonBridgeDex.deploy(WETH_ADDRESS, USDC_ADDRESS, {
    gasLimit: 30000000 // Explicit high gas limit for large contract
  });

  console.log("⏳ Waiting for deployment confirmation...");
  await monBridgeDex.waitForDeployment();
  const contractAddress = await monBridgeDex.getAddress();

  console.log("✅ MonBridgeDex deployed to:", contractAddress);
  console.log("\n📋 Contract Details:");
  console.log("   - Network: Monad");
  console.log("   - Address:", contractAddress);
  console.log("   - Deployer:", deployer.address);
  console.log("   - Block:", await hre.ethers.provider.getBlockNumber());
  
  // Save deployment info
  const fs = require('fs');
  const deploymentInfo = {
    network: "monad",
    contractAddress: contractAddress,
    deployer: deployer.address,
    deployedAt: new Date().toISOString(),
    blockNumber: await hre.ethers.provider.getBlockNumber()
  };
  
  fs.writeFileSync(
    'deployment-info.json',
    JSON.stringify(deploymentInfo, null, 2)
  );
  
  console.log("\n💾 Deployment info saved to deployment-info.json");
  console.log("\n🎉 Deployment complete!");
  console.log("\n⚠️  Next steps:");
  console.log("   1. Add Uniswap V2 routers using addRouterV2()");
  console.log("   2. Add Uniswap V3 routers using addRouterV3()");
  console.log("   3. Use the HTML interface to manage and test swaps");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });

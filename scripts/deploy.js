const hre = require("hardhat");

async function main() {
  console.log("🚀 Deploying MonBridgeDex to Monad...\n");

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("📝 Deploying with account:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", hre.ethers.formatEther(balance), "MON\n");

  // Deploy contract
  console.log("⏳ Deploying MonBridgeDex contract...");
  const MonBridgeDex = await hre.ethers.getContractFactory("MonBridgeDex");
  const monBridgeDex = await MonBridgeDex.deploy();

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

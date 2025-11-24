const hre = require("hardhat");
const fs = require('fs');

async function main() {
  console.log("🔍 Verifying MonBridgeDex deployment...\n");

  // Read deployment info
  if (!fs.existsSync('deployment-info.json')) {
    console.log("❌ No deployment-info.json found. Please deploy first.");
    return;
  }

  const deploymentInfo = JSON.parse(fs.readFileSync('deployment-info.json', 'utf8'));
  const contractAddress = deploymentInfo.contractAddress;

  console.log("📋 Checking contract at:", contractAddress);

  // Get contract
  const MonBridgeDex = await hre.ethers.getContractFactory("MonBridgeDex");
  const contract = MonBridgeDex.attach(contractAddress);

  try {
    // Check owner
    const owner = await contract.owner();
    console.log("✅ Owner:", owner);

    // Check V2 routers count
    const v2Count = await contract.getRoutersV2Count();
    console.log("✅ V2 Routers:", v2Count.toString());

    // Check V3 routers count
    const v3Count = await contract.getRoutersV3Count();
    console.log("✅ V3 Routers:", v3Count.toString());

    // Check fee tiers
    const feeTiers = await contract.getV3FeeTiers();
    console.log("✅ V3 Fee Tiers:", feeTiers.map(f => f.toString()).join(", "));

    // Check fee percentage
    const feePercent = await contract.feePercent();
    console.log("✅ Fee Percentage:", feePercent.toString(), "bps");

    console.log("\n🎉 Contract verification complete!");
    
  } catch (error) {
    console.log("❌ Verification failed:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

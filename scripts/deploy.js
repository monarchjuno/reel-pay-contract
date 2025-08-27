const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🚀 Starting deployment...");

  // Get signers
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // Deploy MockUSDC
  console.log('📦 Deploying MockUSDC...');
  const USDC = await hre.ethers.getContractFactory('MockUSDC');
  const usdc = await USDC.deploy();
  await usdc.waitForDeployment();
  const usdcAddress = await usdc.getAddress();
  console.log("MockUSDC deployed to:", usdcAddress);

  // For testing, we'll use deployer as mock access control and platform wallet
  const mockAccessControl = deployer.address; // Simplified for testing
  const platformWallet = deployer.address;

  // Deploy ReelPayRegistry
  console.log("\n📦 Deploying ReelPayRegistry...");
  const ReelPayRegistry = await hre.ethers.getContractFactory("ReelPayRegistry");
  const registry = await ReelPayRegistry.deploy(mockAccessControl, platformWallet);
  await registry.waitForDeployment();
  const registryAddress = await registry.getAddress();
  console.log("ReelPayRegistry deployed to:", registryAddress);

  // Deploy ReelPayFundManager
  console.log("\n📦 Deploying ReelPayFundManager...");
  const ReelPayFundManager = await hre.ethers.getContractFactory("ReelPayFundManager");
  const fundManager = await ReelPayFundManager.deploy(usdcAddress, registryAddress, mockAccessControl);
  await fundManager.waitForDeployment();
  const fundManagerAddress = await fundManager.getAddress();
  console.log("ReelPayFundManager deployed to:", fundManagerAddress);

  // Deploy ReelPayRewardLogic
  console.log("\n📦 Deploying ReelPayRewardLogic...");
  const ReelPayRewardLogic = await hre.ethers.getContractFactory("ReelPayRewardLogic");
  const rewardLogic = await ReelPayRewardLogic.deploy(registryAddress, fundManagerAddress, mockAccessControl);
  await rewardLogic.waitForDeployment();
  const rewardLogicAddress = await rewardLogic.getAddress();
  console.log("ReelPayRewardLogic deployed to:", rewardLogicAddress);

  // Setup initial data
  console.log("\n⚙️ Setting up initial data...");
  console.log("\n💰 Minting USDC to test accounts...");
  const testAccounts = (await hre.ethers.getSigners()).slice(0, 3);
  for (const account of testAccounts) {
    await usdc.mint(account.address, hre.ethers.parseEther("10000"));
    console.log(`Minted 10,000 USDC to ${account.address}`);
  }

  // Save deployment info
  const deploymentInfo = {
    network: "localhost",
    contracts: {
      MockUSDC: usdcAddress,
      ReelPayRegistry: registryAddress,
      ReelPayRewardLogic: rewardLogicAddress,
      ReelPayFundManager: fundManagerAddress,
    },
    deployedAt: new Date().toISOString(),
  };

  // Save deployment info to JSON file
  const deploymentsDir = path.join(__dirname, "../deployments");
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const deploymentPath = path.join(deploymentsDir, "localhost.json");
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));

  // Generate TypeScript file with contract addresses for frontend
  const tsContent = `// Auto-generated file - DO NOT EDIT
// Generated at: ${new Date().toISOString()}

export const CONTRACTS = {
  USDC: "${usdcAddress}" as const,
  ReelPayRegistry: "${registryAddress}" as const,
  ReelPayRewardLogic: "${rewardLogicAddress}" as const,
  ReelPayFundManager: "${fundManagerAddress}" as const,
} as const;
`;

  const frontendPath = path.join(__dirname, "../../../apps/reel-pay/src/lib/contracts.ts");
  fs.writeFileSync(frontendPath, tsContent);

  console.log("\n✅ Deployment complete!");
  console.log("📄 Deployment info saved to:", deploymentPath);
  console.log("📄 Contracts info saved to:", frontendPath);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

import { ethers, artifacts, network } from "hardhat";
import * as fs from "fs";
import * as path from "path";

async function saveFrontendArtifacts(addressMap: Record<string, string>) {
  const contractsDir = path.join(__dirname, "../../../apps/reel-pay/src/contracts");
  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir, { recursive: true });
  }

  for (const [name, address] of Object.entries(addressMap)) {
    const artifact = await artifacts.readArtifact(name);
    fs.writeFileSync(
      path.join(contractsDir, `${name}.json`),
      JSON.stringify({ address, abi: artifact.abi }, null, 2)
    );
  }

  console.log("Contract addresses and ABIs saved to frontend");
}

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Network:", network.name);
  console.log("Deploying contracts with:", deployer.address);
  console.log(
    "Deployer balance:",
    (await deployer.provider.getBalance(deployer.address)).toString()
  );

  const platformWallet = process.env.PLATFORM_WALLET || deployer.address;
  const backendAddress = process.env.BACKEND_ADDRESS || deployer.address;

  // 1) Deploy AccessControl
  const Access = await ethers.getContractFactory("ReelPayAccessControl");
  const access = await Access.deploy();
  await access.waitForDeployment();
  const accessAddress = await access.getAddress();
  console.log("ReelPayAccessControl:", accessAddress);

  // Grant BACKEND_ROLE if provided
  const BACKEND_ROLE = await access.BACKEND_ROLE();
  if (backendAddress) {
    const tx = await access.grantRole(BACKEND_ROLE, backendAddress);
    await tx.wait();
    console.log("Granted BACKEND_ROLE to:", backendAddress);
  }

  // 2) Stablecoin (use provided or deploy MockKRWT)
  let stablecoinAddress = process.env.STABLECOIN_ADDRESS;
  if (!stablecoinAddress) {
    const MockKRWT = await ethers.getContractFactory("MockKRWT");
    const krwt = await MockKRWT.deploy();
    await krwt.waitForDeployment();
    stablecoinAddress = await krwt.getAddress();
    console.log("MockKRWT (Korean Won Token):", stablecoinAddress);
  } else {
    console.log("Using external stablecoin:", stablecoinAddress);
  }

  // 3) Registry
  const Registry = await ethers.getContractFactory("ReelPayRegistry");
  const registry = await Registry.deploy(accessAddress, platformWallet);
  await registry.waitForDeployment();
  const registryAddress = await registry.getAddress();
  console.log("ReelPayRegistry:", registryAddress);

  // 4) FundManager
  const FundManager = await ethers.getContractFactory("ReelPayFundManager");
  const fundManager = await FundManager.deploy(stablecoinAddress!, registryAddress, accessAddress);
  await fundManager.waitForDeployment();
  const fundManagerAddress = await fundManager.getAddress();
  console.log("ReelPayFundManager:", fundManagerAddress);

  // 5) RewardLogic
  const RewardLogic = await ethers.getContractFactory("ReelPayRewardLogic");
  const rewardLogic = await RewardLogic.deploy(registryAddress, fundManagerAddress, accessAddress);
  await rewardLogic.waitForDeployment();
  const rewardLogicAddress = await rewardLogic.getAddress();
  console.log("ReelPayRewardLogic:", rewardLogicAddress);

  // Wire FundManager -> RewardLogic
  const tx = await fundManager.setRewardLogic(rewardLogicAddress);
  await tx.wait();
  console.log("FundManager setRewardLogic ok");

  await saveFrontendArtifacts({
    ReelPayAccessControl: accessAddress,
    ReelPayRegistry: registryAddress,
    ReelPayFundManager: fundManagerAddress,
    ReelPayRewardLogic: rewardLogicAddress,
    MockKRWT: stablecoinAddress!,
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

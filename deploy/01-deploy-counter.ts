import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());

  const Counter = await ethers.getContractFactory("Counter");
  const counter = await Counter.deploy();

  await counter.waitForDeployment();

  const counterAddress = await counter.getAddress();
  console.log("Counter deployed to:", counterAddress);

  // Save the contract address and ABI for frontend use
  const fs = require("fs");
  const path = require("path");

  const contractsDir = path.join(__dirname, "../../../apps/reel-pay/src/contracts");
  
  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir, { recursive: true });
  }

  fs.writeFileSync(
    path.join(contractsDir, "Counter.json"),
    JSON.stringify({
      address: counterAddress,
      abi: [
        "function count() view returns (uint256)",
        "function increment()",
        "event CountIncremented(uint256 newCount)"
      ]
    }, null, 2)
  );

  console.log("Contract address and ABI saved to frontend");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

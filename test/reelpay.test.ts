import { expect } from "chai";
import { ethers } from "hardhat";
// Using ethers runtime contracts without TypeChain typings in tests for simplicity

const toBN = (v: string | number, decimals = 6) => ethers.parseUnits(v.toString(), decimals);

function toBytes32(text: string) {
  return ethers.keccak256(ethers.toUtf8Bytes(text));
}

describe("ReelPay core suite", () => {
  it("DPVR escrow release and claim, and PVR direct distribution should work", async () => {
    const [deployer, platform, backend, advertiser, marketer, buyer] = await ethers.getSigners();

    // AccessControl
    const Access = await ethers.getContractFactory("ReelPayAccessControl");
    const access = (await Access.deploy()) as any;
    await access.waitForDeployment();

    // Grant BACKEND_ROLE
    const BACKEND_ROLE = await access.BACKEND_ROLE();
    await (await access.grantRole(BACKEND_ROLE, backend.address)).wait();

    // Stablecoin (MockKRWT)
    const MockKRWTF = await ethers.getContractFactory("MockKRWT");
    const krwt = (await MockKRWTF.deploy()) as any;
    await krwt.waitForDeployment();

    // Registry
    const Registry = await ethers.getContractFactory("ReelPayRegistry");
    const registry = (await Registry.deploy(
      await access.getAddress(),
      platform.address
    )) as any;
    await registry.waitForDeployment();

    // FundManager
    const Fund = await ethers.getContractFactory("ReelPayFundManager");
    const fund = (await Fund.deploy(
      await krwt.getAddress(),
      await registry.getAddress(),
      await access.getAddress()
    )) as any;
    await fund.waitForDeployment();

    // RewardLogic
    const Logic = await ethers.getContractFactory("ReelPayRewardLogic");
    const logic = (await Logic.deploy(
      await registry.getAddress(),
      await fund.getAddress(),
      await access.getAddress()
    )) as any;
    await logic.waitForDeployment();

    await (await fund.setRewardLogic(await logic.getAddress())).wait();

    // Register advertiser and marketer
    await (await registry.registerAdvertiser(advertiser.address, "Shop A", 500, toBN(10000))).wait(); // 5% default, 10000 KRWT min
    await (await registry.registerMarketer(marketer.address, "marketerX")).wait();

    // Set commission policy for product
    const productId = toBytes32("SKU-1");
    await (await registry.setCommissionPolicy(productId, 1000, 200, true)).wait(); // 10% to marketer, 2% to platform

    // --- DPVR flow ---
    // Advertiser funds escrow
    await (await krwt.mint(advertiser.address, toBN(1_000_000))).wait();
    await (await krwt.connect(advertiser).approve(await fund.getAddress(), toBN(1_000_000))).wait();
    await (await fund.connect(advertiser).depositEscrow(toBN(500_000))).wait();

    const orderId1 = toBytes32("ORDER-1");

    // Backend submits approved order
    const orderAmount = toBN(100_000); // 100,000 KRW
    await (
      await logic
        .connect(backend)
        .submitApprovedOrder(orderId1, productId, advertiser.address, marketer.address, buyer.address, orderAmount)
    ).wait();

    // Marketer claims rewards
    const claimableBefore = await fund.claimableRewards(marketer.address);
    expect(claimableBefore).to.equal(toBN(10000)); // 10% of 100,000 KRW

    await (await fund.connect(marketer).claimRewards()).wait();

    expect(await krwt.balanceOf(marketer.address)).to.equal(toBN(10000)); // 10,000 KRW
    // Platform fee should be 2
    expect(await fund.claimableRewards(platform.address)).to.equal(toBN(2000)); // 2,000 KRW

    // --- PVR flow ---
    const orderId2 = toBytes32("ORDER-2");
    const orderAmount2 = toBN(50_000); // 50,000 KRW

    // Buyer has KRWT and approves FundManager
    await (await krwt.mint(buyer.address, toBN(100_000))).wait();
    await (await krwt.connect(buyer).approve(await fund.getAddress(), toBN(100_000))).wait();

    const advertiserBefore = await krwt.balanceOf(advertiser.address);
    await (
      await logic
        .connect(buyer)
        .processDirectPayment(orderId2, productId, advertiser.address, marketer.address, orderAmount2)
    ).wait();

    // Check balances: marketer 10% of 50 = 5, platform 2% of 50 = 1, advertiser receives +44
    expect(await krwt.balanceOf(marketer.address)).to.equal(toBN(15000)); // 10,000 + 5,000 KRW
    expect(await krwt.balanceOf(platform.address)).to.equal(toBN(1000)); // 1,000 KRW
    const advertiserAfter = await krwt.balanceOf(advertiser.address);
    expect(advertiserAfter).to.equal(advertiserBefore + toBN(44));
  });
});

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/IAccessControl.sol";
import "../interfaces/IReelPayRegistry.sol";
import "../interfaces/IReelPayFundManager.sol";

contract ReelPayRewardLogic {
    IReelPayRegistry public immutable registry;
    IReelPayFundManager public immutable fundManager;
    IAccessControl public accessControl;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant BACKEND_ROLE = keccak256("BACKEND_ROLE");

    event OrderProcessed(
        bytes32 indexed orderId,
        address indexed advertiser,
        address indexed marketer,
        uint256 orderAmount,
        uint256 marketerReward,
        uint256 platformFee
    );

    event DirectPaymentProcessed(
        bytes32 indexed orderId,
        address indexed advertiser,
        address indexed marketer,
        uint256 orderAmount,
        uint256 marketerReward,
        uint256 platformFee
    );

    constructor(address _registry, address _fundManager, address _accessControl) {
        require(_registry != address(0), "invalid registry");
        require(_fundManager != address(0), "invalid fundManager");
        require(_accessControl != address(0), "invalid accessControl");
        registry = IReelPayRegistry(_registry);
        fundManager = IReelPayFundManager(_fundManager);
        accessControl = IAccessControl(_accessControl);
    }

    modifier onlyBackend() {
        require(accessControl.hasRole(BACKEND_ROLE, msg.sender), "Backend only");
        _;
    }

    function calculateRewards(bytes32 productId, uint256 orderAmount)
        public
        view
        returns (uint256 marketerReward, uint256 platformFee)
    {
        (uint256 marketerRate, uint256 platformRate, bool isActive) = registry.policies(productId);
        require(isActive, "Invalid product policy");
        marketerReward = (orderAmount * marketerRate) / 10000;
        platformFee = (orderAmount * platformRate) / 10000;
    }

    // DPVR: Off-chain approved order processing
    function submitApprovedOrder(
        bytes32 orderId,
        bytes32 productId,
        address advertiser,
        address marketer,
        address buyer,
        uint256 orderAmount
    ) external onlyBackend {
        (, , bool advertiserActive, , , ) = registry.advertisers(advertiser);
        (, , bool marketerActive, , ) = registry.marketers(marketer);
        require(advertiserActive, "Invalid advertiser");
        require(marketerActive, "Invalid marketer");

        fundManager.recordOrder(orderId, advertiser, marketer, buyer, orderAmount);

        (uint256 marketerReward, uint256 platformFee) = calculateRewards(productId, orderAmount);
        fundManager.releaseReward(orderId, marketerReward, platformFee);

        emit OrderProcessed(orderId, advertiser, marketer, orderAmount, marketerReward, platformFee);
    }

    // PVR: Direct on-chain payment and distribution
    function processDirectPayment(
        bytes32 orderId,
        bytes32 productId,
        address advertiser,
        address marketer,
        uint256 orderAmount
    ) external {
        (, , bool advertiserActive, , , ) = registry.advertisers(advertiser);
        (, , bool marketerActive, , ) = registry.marketers(marketer);
        require(advertiserActive, "Invalid advertiser");
        require(marketerActive, "Invalid marketer");

        (uint256 marketerReward, uint256 platformFee) = calculateRewards(productId, orderAmount);
        fundManager.payAndDistribute(orderId, advertiser, marketer, msg.sender, orderAmount, marketerReward, platformFee);

        emit DirectPaymentProcessed(orderId, advertiser, marketer, orderAmount, marketerReward, platformFee);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

import "../interfaces/IReelPayRegistry.sol";

contract ReelPayFundManager is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable stablecoin; // e.g., USDC
    IReelPayRegistry public immutable registry;
    IAccessControl public accessControl;

    address public rewardLogic; // authorized reward logic contract

    // Escrow balances for DPVR flow (by advertiser)
    mapping(address => uint256) public escrowBalances;

    // Claimable rewards (Pull over Push pattern)
    mapping(address => uint256) public claimableRewards;

    struct Transaction {
        bytes32 orderId;
        address advertiser;
        address marketer;
        address buyer;
        uint256 orderAmount;
        uint256 marketerReward;
        uint256 platformFee;
        uint256 timestamp;
        bool isSettled;
    }

    mapping(bytes32 => Transaction) public transactions;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event EscrowDeposited(address indexed advertiser, uint256 amount);
    event RewardReleased(bytes32 indexed orderId, address indexed marketer, uint256 marketerReward, uint256 platformFee);
    event PaymentDistributed(
        bytes32 indexed orderId,
        address indexed advertiser,
        address indexed marketer,
        uint256 totalAmount,
        uint256 marketerReward,
        uint256 platformFee
    );
    event RewardsClaimed(address indexed account, uint256 amount);
    event RewardLogicUpdated(address indexed newRewardLogic);

    constructor(address _stablecoin, address _registry, address _accessControl) {
        require(_stablecoin != address(0), "invalid stablecoin");
        require(_registry != address(0), "invalid registry");
        require(_accessControl != address(0), "invalid accessControl");
        stablecoin = IERC20(_stablecoin);
        registry = IReelPayRegistry(_registry);
        accessControl = IAccessControl(_accessControl);
    }

    modifier onlyRewardLogic() {
        require(msg.sender == rewardLogic, "Only reward logic");
        _;
    }

    function setRewardLogic(address _rewardLogic) external {
        require(accessControl.hasRole(ADMIN_ROLE, msg.sender), "Admin only");
        require(_rewardLogic != address(0), "invalid address");
        rewardLogic = _rewardLogic;
        emit RewardLogicUpdated(_rewardLogic);
    }

    // DPVR: Advertisers deposit escrow funds
    function depositEscrow(uint256 amount) external nonReentrant {
        (, , bool isActive, , , ) = registry.advertisers(msg.sender);
        require(isActive, "Not registered advertiser");
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        escrowBalances[msg.sender] += amount;
        emit EscrowDeposited(msg.sender, amount);
    }

    // DPVR: Record approved order (called by RewardLogic)
    function recordOrder(
        bytes32 orderId,
        address advertiser,
        address marketer,
        address buyer,
        uint256 orderAmount
    ) external onlyRewardLogic {
        Transaction storage txn = transactions[orderId];
        require(txn.timestamp == 0, "Order exists");
        txn.orderId = orderId;
        txn.advertiser = advertiser;
        txn.marketer = marketer;
        txn.buyer = buyer;
        txn.orderAmount = orderAmount;
        txn.timestamp = block.timestamp;
    }

    // DPVR: Release rewards from escrow to claimable balances
    function releaseReward(bytes32 orderId, uint256 marketerReward, uint256 platformFee)
        external
        onlyRewardLogic
        nonReentrant
    {
        Transaction storage txn = transactions[orderId];
        require(txn.timestamp != 0, "Unknown order");
        require(!txn.isSettled, "Already settled");
        uint256 total = marketerReward + platformFee;
        require(escrowBalances[txn.advertiser] >= total, "Insufficient escrow");

        escrowBalances[txn.advertiser] -= total;
        claimableRewards[txn.marketer] += marketerReward;
        claimableRewards[registry.platformWallet()] += platformFee;

        txn.marketerReward = marketerReward;
        txn.platformFee = platformFee;
        txn.isSettled = true;

        emit RewardReleased(orderId, txn.marketer, marketerReward, platformFee);
    }

    // PVR: Atomic payment and distribution from buyer funds
    function payAndDistribute(
        bytes32 orderId,
        address advertiser,
        address marketer,
        address buyer,
        uint256 totalAmount,
        uint256 marketerReward,
        uint256 platformFee
    ) external onlyRewardLogic nonReentrant {
        uint256 advertiserAmount = totalAmount - marketerReward - platformFee;

        // Transfer from buyer (buyer must approve this contract)
        stablecoin.safeTransferFrom(buyer, advertiser, advertiserAmount);
        stablecoin.safeTransferFrom(buyer, marketer, marketerReward);
        stablecoin.safeTransferFrom(buyer, registry.platformWallet(), platformFee);

        transactions[orderId] = Transaction({
            orderId: orderId,
            advertiser: advertiser,
            marketer: marketer,
            buyer: buyer,
            orderAmount: totalAmount,
            marketerReward: marketerReward,
            platformFee: platformFee,
            timestamp: block.timestamp,
            isSettled: true
        });

        emit PaymentDistributed(orderId, advertiser, marketer, totalAmount, marketerReward, platformFee);
    }

    // Pull pattern: users claim their rewards
    function claimRewards() external nonReentrant {
        uint256 amount = claimableRewards[msg.sender];
        require(amount > 0, "No rewards to claim");
        claimableRewards[msg.sender] = 0;
        stablecoin.safeTransfer(msg.sender, amount);
        emit RewardsClaimed(msg.sender, amount);
    }
}

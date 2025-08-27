// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/IAccessControl.sol";
import "../interfaces/IReelPayRegistry.sol";

contract ReelPayRegistry is IReelPayRegistry {
    IAccessControl public accessControl;
    address public platformWallet;

    mapping(address => Advertiser) public advertisers;
    mapping(address => Marketer) public marketers;
    mapping(bytes32 => CommissionPolicy) public policies;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ADVERTISER_ROLE = keccak256("ADVERTISER_ROLE");

    event AdvertiserRegistered(address indexed advertiser, string name);
    event AdvertiserStatusUpdated(address indexed advertiser, bool isActive);
    event MarketerRegistered(address indexed marketer, string handle);
    event MarketerStatusUpdated(address indexed marketer, bool isActive);
    event PolicyUpdated(bytes32 indexed productId, uint256 marketerRate, uint256 platformRate, bool isActive);
    event PlatformWalletUpdated(address indexed newWallet);

    constructor(address _accessControl, address _platformWallet) {
        require(_accessControl != address(0), "invalid accessControl");
        require(_platformWallet != address(0), "invalid platformWallet");
        accessControl = IAccessControl(_accessControl);
        platformWallet = _platformWallet;
    }

    modifier onlyAdmin() {
        require(accessControl.hasRole(ADMIN_ROLE, msg.sender), "Admin only");
        _;
    }

    function setPlatformWallet(address _platformWallet) external onlyAdmin {
        require(_platformWallet != address(0), "invalid wallet");
        platformWallet = _platformWallet;
        emit PlatformWalletUpdated(_platformWallet);
    }

    function registerAdvertiser(
        address wallet,
        string calldata name,
        uint256 defaultCommissionRate,
        uint256 minOrderAmount
    ) external onlyAdmin {
        Advertiser storage a = advertisers[wallet];
        a.wallet = wallet;
        a.name = name;
        a.isActive = true;
        a.defaultCommissionRate = defaultCommissionRate;
        a.minOrderAmount = minOrderAmount;
        if (a.createdAt == 0) a.createdAt = block.timestamp;
        emit AdvertiserRegistered(wallet, name);
    }

    function setAdvertiserActive(address wallet, bool isActive) external onlyAdmin {
        advertisers[wallet].isActive = isActive;
        emit AdvertiserStatusUpdated(wallet, isActive);
    }

    function registerMarketer(address wallet, string calldata handle) external onlyAdmin {
        Marketer storage m = marketers[wallet];
        m.wallet = wallet;
        m.handle = handle;
        m.isActive = true;
        if (m.createdAt == 0) m.createdAt = block.timestamp;
        emit MarketerRegistered(wallet, handle);
    }

    function setMarketerActive(address wallet, bool isActive) external onlyAdmin {
        marketers[wallet].isActive = isActive;
        emit MarketerStatusUpdated(wallet, isActive);
    }

    function setCommissionPolicy(
        bytes32 productId,
        uint256 marketerRate,
        uint256 platformRate,
        bool isActive
    ) external {
        require(
            accessControl.hasRole(ADMIN_ROLE, msg.sender) ||
                accessControl.hasRole(ADVERTISER_ROLE, msg.sender),
            "Unauthorized"
        );
        policies[productId] = CommissionPolicy({
            marketerRate: marketerRate,
            platformRate: platformRate,
            isActive: isActive
        });
        emit PolicyUpdated(productId, marketerRate, platformRate, isActive);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IReelPayRegistry {
    struct Advertiser {
        address wallet;
        string name;
        bool isActive;
        uint256 defaultCommissionRate; // basis points (100 = 1%)
        uint256 minOrderAmount;
        uint256 createdAt;
    }

    struct Marketer {
        address wallet;
        string handle;
        bool isActive;
        uint256 totalEarned;
        uint256 createdAt;
    }

    struct CommissionPolicy {
        uint256 marketerRate; // basis points
        uint256 platformRate; // basis points
        bool isActive;
    }

    function platformWallet() external view returns (address);

    function advertisers(address)
        external
        view
        returns (
            address wallet,
            string memory name,
            bool isActive,
            uint256 defaultCommissionRate,
            uint256 minOrderAmount,
            uint256 createdAt
        );

    function marketers(address)
        external
        view
        returns (
            address wallet,
            string memory handle,
            bool isActive,
            uint256 totalEarned,
            uint256 createdAt
        );

    function policies(bytes32)
        external
        view
        returns (
            uint256 marketerRate,
            uint256 platformRate,
            bool isActive
        );
}

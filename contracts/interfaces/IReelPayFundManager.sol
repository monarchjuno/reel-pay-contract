// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IReelPayFundManager {
    function releaseReward(bytes32 orderId, uint256 marketerReward, uint256 platformFee) external;

    function payAndDistribute(
        bytes32 orderId,
        address advertiser,
        address marketer,
        address buyer,
        uint256 totalAmount,
        uint256 marketerReward,
        uint256 platformFee
    ) external;

    function recordOrder(
        bytes32 orderId,
        address advertiser,
        address marketer,
        address buyer,
        uint256 orderAmount
    ) external;
}

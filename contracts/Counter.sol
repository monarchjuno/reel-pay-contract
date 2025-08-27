// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Counter {
    uint256 private _count;

    event CountIncremented(uint256 newCount);

    constructor() {
        _count = 0;
    }

    function count() public view returns (uint256) {
        return _count;
    }

    function increment() public {
        _count += 1;
        emit CountIncremented(_count);
    }
}

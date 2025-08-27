// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockKRWT - Korean Won Stablecoin for Testing
 * @dev Mock implementation of a KRW-pegged stablecoin
 */
contract MockKRWT is ERC20 {
    uint8 private _decimals = 18; // Using 18 decimals like most tokens

    constructor() ERC20("Korean Won Token", "KRWT") {}

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    // Faucet function for testing - gives 10,000 KRWT
    function faucet() public {
        _mint(msg.sender, 10000 * 10**decimals());
    }

    // Demo function: Simulate exchange rate (1 KRWT = 1 KRW)
    function getExchangeRate() public pure returns (uint256) {
        return 1; // 1 KRWT = 1 KRW
    }
}

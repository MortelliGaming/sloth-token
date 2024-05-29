// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DiamondhandedSloth is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    constructor()
        ERC20("Diamondhanded Sloth", "SLTH")
        ERC20Permit("DiamondhandedSloth")
        Ownable(_msgSender())
    {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
        renounceOwnership();
    }
}

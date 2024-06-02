// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenLocker is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    struct Lock {
        uint256 amount;
        uint256 unlockTime;
    }

    // Mapping from user address to token address to list of locks
    mapping(address => mapping(address => Lock[])) public locks;

    event TokensLocked(address indexed user, address indexed token, uint256 amount, uint256 unlockTime);
    event TokensWithdrawn(address indexed user, address indexed token, uint256 amount);

    constructor() {
        // Renounce ownership immediately
        renounceOwnership();
    }

    function lockTokens(address token, uint256 amount, uint256 lockTime) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        require(lockTime > 0, "Lock time must be greater than zero");

        // Transfer tokens from sender to this contract
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Add the lock
        locks[msg.sender][token].push(Lock({
            amount: amount,
            unlockTime: block.timestamp.add(lockTime)
        }));

        emit TokensLocked(msg.sender, token, amount, block.timestamp.add(lockTime));
    }

    function withdrawTokens(address token, uint256 lockIndex) external nonReentrant {
        require(lockIndex < locks[msg.sender][token].length, "Invalid lock index");
        
        Lock storage lock = locks[msg.sender][token][lockIndex];
        require(lock.amount > 0, "No tokens to withdraw");
        require(block.timestamp >= lock.unlockTime, "Tokens are still locked");

        uint256 amount = lock.amount;
        lock.amount = 0;

        // Transfer tokens back to the user
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");

        emit TokensWithdrawn(msg.sender, token, amount);
    }

    function getLocks(address user, address token) external view returns (Lock[] memory) {
        return locks[user][token];
    }

    function getRemainingTime(address user, address token, uint256 lockIndex) external view returns (uint256) {
        require(lockIndex < locks[user][token].length, "Invalid lock index");

        Lock storage lock = locks[user][token][lockIndex];
        if (block.timestamp >= lock.unlockTime) {
            return 0;
        } else {
            return lock.unlockTime.sub(block.timestamp);
        }
    }
}

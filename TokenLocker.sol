// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenLocker is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    struct Lock {
        address token;
        uint256 amount;
        uint256 unlockTime;
    }

    // Mapping from user address to token address to list of locks
    mapping(address => mapping(address => Lock[])) private userLocks;
    mapping(address => address[]) private userTokens;

    event TokensLocked(address indexed user, address indexed token, uint256 amount, uint256 unlockTime);
    event TokensWithdrawn(address indexed user, address indexed token, uint256 amount);

    constructor() Ownable(_msgSender()) {
        // Renounce ownership immediately
        renounceOwnership();
    }

    /**
     * @dev Locks tokens for a specified amount of time.
     * @param token The address of the ERC20 token to be locked.
     * @param amount The amount of tokens to lock.
     * @param lockTime The duration for which the tokens should be locked.
     */
    function lockTokens(address token, uint256 amount, uint256 lockTime) external nonReentrant {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");
        require(lockTime > 0, "Lock time must be greater than zero");

        // Transfer tokens from sender to this contract
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Add the lock
        userLocks[msg.sender][token].push(Lock({
            token: token,
            amount: amount,
            unlockTime: block.timestamp.add(lockTime)
        }));

        // Add the token to user's token list if it's not already there
        if (!isTokenAdded(msg.sender, token)) {
            userTokens[msg.sender].push(token);
        }

        emit TokensLocked(msg.sender, token, amount, block.timestamp.add(lockTime));
    }

    /**
     * @dev Withdraws tokens after the lock period has ended.
     * @param token The address of the ERC20 token to be withdrawn.
     * @param lockIndex The index of the lock to be withdrawn.
     */
    function withdrawTokens(address token, uint256 lockIndex) external nonReentrant {
        require(token != address(0), "Invalid token address");
        require(lockIndex < userLocks[msg.sender][token].length, "Invalid lock index");
        
        Lock storage lock = userLocks[msg.sender][token][lockIndex];
        require(lock.amount > 0, "No tokens to withdraw");
        require(block.timestamp >= lock.unlockTime, "Tokens are still locked");

        uint256 amount = lock.amount;

        // Remove the lock by swapping with the last element and then popping the last element
        uint256 lastLockIndex = userLocks[msg.sender][token].length - 1;
        if (lockIndex != lastLockIndex) {
            userLocks[msg.sender][token][lockIndex] = userLocks[msg.sender][token][lastLockIndex];
        }
        userLocks[msg.sender][token].pop();

        // If no locks are left for this token, remove the token from userTokens
        if (userLocks[msg.sender][token].length == 0) {
            removeToken(msg.sender, token);
        }

        // Transfer tokens back to the user
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");

        emit TokensWithdrawn(msg.sender, token, amount);
    }

    /**
     * @dev Returns all locks for a given user.
     * @param user The address of the user.
     * @return A flat array of all locks.
     */
    function getLocks(address user) external view returns (Lock[] memory) {
        require(user != address(0), "Invalid user address");

        uint256 totalLocks = 0;

        // Calculate the total number of locks
        for (uint256 i = 0; i < userTokens[user].length; i++) {
            totalLocks += userLocks[user][userTokens[user][i]].length;
        }

        // Create a flat array of all locks
        Lock[] memory allLocks = new Lock[](totalLocks);
        uint256 index = 0;

        for (uint256 i = 0; i < userTokens[user].length; i++) {
            address token = userTokens[user][i];
            Lock[] storage locks = userLocks[user][token];
            for (uint256 j = 0; j < locks.length; j++) {
                allLocks[index] = locks[j];
                index++;
            }
        }

        return allLocks;
    }

    /**
     * @dev Returns the remaining time for a specific lock.
     * @param user The address of the user.
     * @param token The address of the ERC20 token.
     * @param lockIndex The index of the lock.
     * @return The remaining time in seconds.
     */
    function getRemainingTime(address user, address token, uint256 lockIndex) external view returns (uint256) {
        require(user != address(0), "Invalid user address");
        require(token != address(0), "Invalid token address");
        require(lockIndex < userLocks[user][token].length, "Invalid lock index");

        Lock storage lock = userLocks[user][token][lockIndex];
        if (block.timestamp >= lock.unlockTime) {
            return 0;
        } else {
            return lock.unlockTime.sub(block.timestamp);
        }
    }

    /**
     * @dev Checks if a token is already added to the user's token list.
     * @param user The address of the user.
     * @param token The address of the ERC20 token.
     * @return True if the token is already added, false otherwise.
     */
    function isTokenAdded(address user, address token) internal view returns (bool) {
        address[] storage tokens = userTokens[user];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Removes a token from the user's token list if no locks are left.
     * @param user The address of the user.
     * @param token The address of the ERC20 token.
     */
    function removeToken(address user, address token) internal {
        address[] storage tokens = userTokens[user];
        uint256 tokenCount = tokens.length;
        for (uint256 i = 0; i < tokenCount; i++) {
            if (tokens[i] == token) {
                tokens[i] = tokens[tokenCount - 1];
                tokens.pop();
                break;
            }
        }
    }
}

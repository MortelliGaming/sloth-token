// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MyTokenVesting
 * @dev A contract for token vesting with configurable schedules.
 */
contract MyTokenVesting is Context, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        uint256 totalAmount;        // Total amount of tokens to be vested
        uint256 startTime;          // Start time of the vesting schedule
        uint256 cliffDuration;      // Duration in seconds of the cliff period
        uint256 vestingDuration;    // Duration in seconds of the vesting period after the cliff
        uint256 lastReleasedTime;   // Timestamp of the last time tokens were released
    }

    mapping(address => VestingSchedule) private _vestingSchedules; // Mapping of beneficiaries to their vesting schedules

    IERC20 private _token; // The ERC20 token being vested

    event TokensReleased(address indexed beneficiary, uint256 amount);

    /**
     * @dev Constructor to initialize the vesting contract.
     * @param token The address of the ERC20 token to be vested.
     */
    constructor(IERC20 token) Ownable(_msgSender()) {
        _token = token;
    }

    /**
     * @dev Creates a new vesting schedule for a beneficiary.
     * @param beneficiary The address of the beneficiary.
     * @param totalAmount The total amount of tokens to be vested.
     * @param startTime The start time of the vesting schedule.
     * @param cliffDuration The duration of the cliff period.
     * @param vestingDuration The duration of the vesting period after the cliff.
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) external onlyOwner {
        require(beneficiary != address(0), "Vesting: beneficiary is the zero address");
        require(totalAmount > 0, "Vesting: total amount is zero");
        require(cliffDuration <= vestingDuration, "Vesting: cliff is longer than duration");

        VestingSchedule storage vestingSchedule = _vestingSchedules[beneficiary];
        require(vestingSchedule.totalAmount == 0, "Vesting: schedule already exists");

        vestingSchedule.totalAmount = totalAmount;
        vestingSchedule.startTime = startTime;
        vestingSchedule.cliffDuration = cliffDuration;
        vestingSchedule.vestingDuration = vestingDuration;
        vestingSchedule.lastReleasedTime = 0;
    }

    /**
     * @dev Releases vested tokens to a beneficiary.
     * @param beneficiary The address of the beneficiary.
     */
    function release(address beneficiary) external {
        require(beneficiary != address(0), "Vesting: beneficiary is the zero address");

        VestingSchedule storage vestingSchedule = _vestingSchedules[beneficiary];
        require(vestingSchedule.totalAmount > 0, "Vesting: no schedule found");

        uint256 availableAmount = _releasableAmount(vestingSchedule);
        require(availableAmount > 0, "Vesting: no tokens to release");

        _token.safeTransfer(beneficiary, availableAmount);
        emit TokensReleased(beneficiary, availableAmount);

        vestingSchedule.lastReleasedTime = block.timestamp;
    }

    /**
     * @dev Calculates the amount of tokens that are currently available to be released.
     * @param vestingSchedule The vesting schedule of the beneficiary.
     * @return The amount of tokens that can be released.
     */
    function _releasableAmount(VestingSchedule storage vestingSchedule) private view returns (uint256) {
        if (block.timestamp < vestingSchedule.startTime.add(vestingSchedule.cliffDuration)) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp.sub(vestingSchedule.startTime).sub(vestingSchedule.cliffDuration);
        uint256 vestedAmount = timeElapsed.mul(vestingSchedule.totalAmount).div(vestingSchedule.vestingDuration);
        uint256 unreleasedAmount = vestingSchedule.totalAmount.sub(vestedAmount);

        uint256 lastReleaseTime = Math.max(vestingSchedule.startTime.add(vestingSchedule.cliffDuration), vestingSchedule.lastReleasedTime);
        uint256 timeSinceLastRelease = block.timestamp.sub(lastReleaseTime);
        uint256 releasableAmount = unreleasedAmount.mul(timeSinceLastRelease).div(vestingSchedule.vestingDuration);

        return releasableAmount;
    }

    /**
     * @dev Retrieves the vesting schedule of a beneficiary.
     * @param beneficiary The address of the beneficiary.
     * @return totalAmount Total amount of tokens in the vesting schedule.
     * @return startTime Start time of the vesting schedule.
     * @return cliffDuration Duration of the cliff period.
     * @return vestingDuration Duration of the vesting period after the cliff.
     * @return lastReleasedTime Timestamp of the last time tokens were released.
     */
    function getVestingSchedule(address beneficiary) external view returns (
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 lastReleasedTime
    ) {
        VestingSchedule storage vestingSchedule = _vestingSchedules[beneficiary];
        return (
            vestingSchedule.totalAmount,
            vestingSchedule.startTime,
            vestingSchedule.cliffDuration,
            vestingSchedule.vestingDuration,
            vestingSchedule.lastReleasedTime
        );
    }
}

// Challenge: Token Vesting Contract
/*
Create a token vesting contract with the following requirements:

1. The contract should allow an admin to create vesting schedules for different beneficiaries
2. Each vesting schedule should have:
   - Total amount of tokens to be vested
   - Cliff period (time before any tokens can be claimed)
   - Vesting duration (total time for all tokens to vest)
   - Start time
3. After the cliff period, tokens should vest linearly over time
4. Beneficiaries should be able to claim their vested tokens at any time
5. Admin should be able to revoke unvested tokens from a beneficiary

Bonus challenges:
- Add support for multiple token types
- Implement a whitelist for beneficiaries
- Add emergency pause functionality

Here's your starter code:
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TokenVesting is Ownable(msg.sender), Pausable, ReentrancyGuard {
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 amountClaimed;
        bool revoked;
    }

    // Token being vested
    IERC20 public token;

    // Mapping from beneficiary to vesting schedule
    mapping(address => VestingSchedule) public vestingSchedules;

    // Whitelist of beneficiaries
    mapping(address => bool) public whitelist;

    // Events
    event VestingScheduleCreated(address indexed beneficiary, uint256 amount);
    event TokensClaimed(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary);
    event BeneficiaryWhitelisted(address indexed beneficiary);
    event BeneficiaryRemovedFromWhitelist(address indexed beneficiary);

    constructor(address tokenAddress) {
        token = IERC20(tokenAddress);
    }

    // Modifier to check if beneficiary is whitelisted
    modifier onlyWhitelisted(address beneficiary) {
        require(whitelist[beneficiary], "Beneficiary not whitelisted");
        _;
    }

    function addToWhitelist(address beneficiary) external onlyOwner {
        require(beneficiary != address(0), "Invalid address");
        whitelist[beneficiary] = true;
        emit BeneficiaryWhitelisted(beneficiary);
    }

    function removeFromWhitelist(address beneficiary) external onlyOwner {
        whitelist[beneficiary] = false;
        emit BeneficiaryRemovedFromWhitelist(beneficiary);
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 startTime
    ) external onlyOwner onlyWhitelisted(beneficiary) whenNotPaused {
        require(
            startTime > block.timestamp,
            "Start time must be in the future"
        );
        require(beneficiary != address(0), "Invalid address");
        require(amount > 0, "Amount cannot be 0");
        require(cliffDuration > 0, "Cliff duration must be greater than 0");
        require(
            vestingDuration >= cliffDuration,
            "Vesting duration must be greater than or equal to cliff duration"
        );

        require(
            vestingSchedules[beneficiary].totalAmount == 0,
            "Vesting schedule already exists"
        );

        require(
            token.balanceOf(msg.sender) >= amount,
            "Insufficient token balance"
        );

        VestingSchedule memory schedule = VestingSchedule(
            amount,
            startTime,
            cliffDuration,
            vestingDuration,
            0,
            false
        );

        vestingSchedules[beneficiary] = schedule;

        token.transferFrom(msg.sender, address(this), amount);

        emit VestingScheduleCreated(beneficiary, amount);
    }

    function calculateVestedAmount(
        address beneficiary
    ) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (schedule.revoked) {
            return 0;
        }

        if (schedule.totalAmount == 0) {
            return 0;
        }

        if (schedule.amountClaimed == schedule.totalAmount) {
            return 0;
        }

        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount - schedule.amountClaimed;
        }

        uint256 duration = block.timestamp - schedule.startTime;
        uint256 vestedAmount = (schedule.totalAmount * duration) /
            schedule.vestingDuration;

        if (vestedAmount > schedule.totalAmount) {
            vestedAmount = schedule.totalAmount;
        }

        return vestedAmount - schedule.amountClaimed;
    }

    function claimVestedTokens() external nonReentrant whenNotPaused {
        uint256 vestedAmount = calculateVestedAmount(msg.sender);

        require(vestedAmount > 0, "No tokens to claim");

        VestingSchedule storage schedule = vestingSchedules[msg.sender];

        schedule.amountClaimed += vestedAmount;

        token.transfer(msg.sender, vestedAmount);

        emit TokensClaimed(msg.sender, vestedAmount);
    }

    function revokeVesting(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        require(schedule.totalAmount > 0, "No vesting schedule found");

        require(!schedule.revoked, "Vesting already revoked");

        uint256 vestedAmount = calculateVestedAmount(beneficiary);

        uint256 unvestedAmount = schedule.totalAmount - vestedAmount;

        if (unvestedAmount > 0) {
            token.transfer(owner(), unvestedAmount);
        }

        schedule.revoked = true;

        emit VestingRevoked(beneficiary);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

/*
Solution template (key points to implement):

1. VestingSchedule struct should contain:
   - Total amount
   - Start time
   - Cliff duration
   - Vesting duration
   - Amount claimed
   - Revoked status

2. State variables needed:
   - Mapping of beneficiary address to VestingSchedule
   - ERC20 token reference
   - Owner/admin address

3. createVestingSchedule should:
   - Validate input parameters
   - Create new vesting schedule
   - Transfer tokens to contract
   - Emit event

4. calculateVestedAmount should:
   - Check if cliff period has passed
   - Calculate linear vesting based on time passed
   - Account for already claimed tokens
   - Handle revoked status

5. claimVestedTokens should:
   - Calculate claimable amount
   - Update claimed amount
   - Transfer tokens
   - Emit event

6. revokeVesting should:
   - Only allow admin
   - Calculate and transfer unvested tokens back
   - Mark schedule as revoked
   - Emit event
*/

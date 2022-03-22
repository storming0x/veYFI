// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "forge-std/console.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";
import {TestFixture} from "./utils/TestFixture.sol";
import "./NextVe.sol";
import "../Gauge.sol";

contract VeTest is TestFixture {

    address public alice = address(10);
    address public bob = address(11);

    uint256 public constant MAX_LOCK_TIME = 4 * 365 * 86400; // 4 years
    uint256 public constant DELTA = 10**7;
    uint256 public constant MULTIPLIER = 10**18;
    uint256 public constant MIN_FUZZ_RANGE = 10 * 10**18;
    uint256 public constant MAX_FUZZ_RANGE = 1000 * 10**22;
    uint256 public constant BASIS_POINTS = 10000;
    

    // setup is run on before each test
    function setUp() public override {
        // setup ve
        super.setUp();

        skip(1 hours);
    }

    function setupAccounts(uint256 _amount, address _a, address _b) internal {
        tip(address(yfi), _a, _amount);
        tip(address(yfi), _b, _amount);

        hoax(_a);
        yfi.approve(address(veYFI), _amount * 10);

        hoax(_b);
        yfi.approve(address(veYFI), _amount * 10);
    }

    function setupAccountsAandB(uint256 _amount) internal {
        setupAccounts(_amount, alice, bob);
    }

    function skipTimeToBeginNextWeek() internal {
        // Move to timing which is good for testing - beginning of a UTC week
        skip((block.timestamp / 1 weeks + 1) * 1 weeks - block.timestamp);
    }

    function lockYfiFor(uint256 _amount, uint256 _lockTime, address _user) internal {
        hoax(_user);
        veYFI.create_lock(_amount, block.timestamp + _lockTime);
    }

    function testSmallQueuedRewardsDurationExtension(uint256 _amount) public {
        // setup
        vm_std_cheats.assume(_amount >= MIN_FUZZ_RANGE && _amount <= MAX_FUZZ_RANGE);        
        Gauge gauge = createGauge(address(vault));

        tip(address(yfi), gov, _amount * 2);
        hoax(gov);
        yfi.approve(address(gauge), _amount * 2);

        //execution
        hoax(gov);
        gauge.queueNewRewards(_amount);
        uint256 finish = gauge.periodFinish();
        // distribution started, do not extend the duration unless rewards are 120% of what has been distributed.
        skip(24 * 3600);
        hoax(gov);
        // Should have distributed 1/7, adding 1% will not trigger an update.
        uint256 onePercent = _amount - (_amount * 9900)/10000;
        gauge.queueNewRewards(onePercent);

        //asserts
        assertEq(gauge.queuedRewards(), onePercent);
        assertEq(gauge.periodFinish(), finish);
        skip(10);

        // If more than 120% of what has been distributed is queued -> make a new period
        uint256 hundredTwentyPercent = (_amount/ 7) + ((_amount/7 * 2000)/BASIS_POINTS);
        hoax(gov);
        gauge.queueNewRewards(hundredTwentyPercent);
        assertNeq(gauge.periodFinish(), finish);
    }

    function testSetDuration() public {
        // setup
        uint256 _amount = 10**20;
        uint256 _duration = 28 * 3600 * 24;
        // vm_std_cheats.assume(_amount >= MIN_FUZZ_RANGE && _amount <= MAX_FUZZ_RANGE);
        // vm_std_cheats.assume(_duration >= 28 * 3600 * 24 && _amount <= 1460 * 3600 * 24);

        Gauge gauge = createGauge(address(vault));

        tip(address(yfi), gov, _amount * 2);
        hoax(gov);
        yfi.approve(address(gauge), _amount * 2);
        hoax(gov);
        gauge.queueNewRewards(_amount);

        uint256 finish = gauge.periodFinish();
        uint256 rate = gauge.rewardRate();
        uint256 time = block.timestamp;
        
        // execution
        hoax(gov);
        gauge.setDuration(_duration);

        //asserts
        console.log("rate", rate);
        assertApproxEq(gauge.rewardRate(), rate/2, 10**12);
        // assertEq(gauge.duration(), _duration);
        // assertNeq(gauge.periodFinish(), finish);
        // assertApproxEq(gauge.periodFinish(), time + _duration, 10**4);
    }


}
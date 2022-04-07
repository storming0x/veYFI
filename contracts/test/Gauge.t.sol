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
    // TODO: uncomment this
    // function testSetDuration(uint256 _amount, uint256 _duration) public {
    //     // setup
    //     uint256 MIN_DURATION = 28 * 3600 * 24;
    //     uint256 MAX_DURATION = 365 * 3600 * 24;
    //     vm_std_cheats.assume(_amount >= MIN_FUZZ_RANGE && _amount <= MAX_FUZZ_RANGE);
    //     vm_std_cheats.assume(_duration >= MIN_DURATION  && _duration <= MAX_DURATION);

    //     Gauge gauge = createGauge(address(vault));

    //     tip(address(yfi), gov, _amount * 2);
    //     hoax(gov);
    //     yfi.approve(address(gauge), _amount * 2);
    //     hoax(gov);
    //     gauge.queueNewRewards(_amount);

    //     uint256 finish = gauge.periodFinish();
    //     console.log("finish", finish);
    //     uint256 rate = gauge.rewardRate();
    //     console.log("rate before", rate);
    //     uint256 time = block.timestamp;
    //     console.log("time", time);
        
    //     // execution
    //     console.log("setDuration step");
    //     hoax(gov);
    //     gauge.setDuration(_duration);

    //     //asserts
    //     console.log("rate", rate/2);
    //     console.log("gauge.rewardRate()", gauge.rewardRate());
    //     assertApproxEq(gauge.rewardRate(), rate/2, 10**13);
    //     assertEq(gauge.duration(), _duration);
    //     assertNeq(gauge.periodFinish(), finish);
    //     assertApproxEq(gauge.periodFinish(), time + _duration, 10**2);
    // }

    function testDistributionFullRewards() public {
        // setup
        uint256 _amount = 10 **18;
        //vm_std_cheats.assume(_amount >= MIN_FUZZ_RANGE && _amount <= MAX_FUZZ_RANGE);
    }
}
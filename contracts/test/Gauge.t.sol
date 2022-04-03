// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Token} from "./Token.sol";
import {Gauge} from "../Gauge.sol";
import {ExtraReward} from "../ExtraReward.sol";

import {TestFixture} from "./utils/TestFixture.sol";

contract TestGauge is TestFixture {
    uint256 public constant MIN_FUZZ_RANGE = 10 * 10**18;
    uint256 public constant MAX_FUZZ_RANGE = 1000 * 10**22;

    function setUp() public override {
        super.setUp();

        skip(1 hours);
    }

    function testSweep(uint256 _amount) public {
        vm_std_cheats.assume(
            _amount >= MIN_FUZZ_RANGE && _amount <= MAX_FUZZ_RANGE
        );

        Gauge gauge = Gauge(createGauge(address(vault)));
        Token yfo = createToken("YFO");
        yfo.mint(address(gauge), _amount);

        vm_std_cheats.expectRevert("Ownable: caller is not the owner");
        hoax(whale);
        gauge.sweep(address(yfo));
        vm_std_cheats.expectRevert("protected token");
        hoax(gov);
        gauge.sweep(address(yfi));
        vm_std_cheats.expectRevert("protected token");
        hoax(gov);
        gauge.sweep(address(vault));

        vm_std_cheats.prank(gov);
        gauge.sweep(address(yfo));
        assertEq(yfo.balanceOf(address(gov)), _amount);
    }

    // @dev _amount represents amount of yfi to distribute
    function testSmallQueuedRewardsDurationExtension(uint256 _amount) public {
        vm_std_cheats.assume(
            _amount >= MIN_FUZZ_RANGE && _amount <= MAX_FUZZ_RANGE
        );

        Gauge gauge = Gauge(createGauge(address(vault)));
        yfi.mint(gov, _amount * 2);
        hoax(gov);
        yfi.approve(address(gauge), _amount * 2);

        hoax(gov);
        gauge.queueNewRewards(_amount);
        uint256 finish = gauge.periodFinish();
        // distribution started, do not extend the duration unless rewards are 120% of what has been distributed.
        skip(1 days);
        // Should have distributed 1/7, adding 1% will not trigger an update.
        hoax(gov);
        gauge.queueNewRewards(_amount / 100);
        assertEq(gauge.queuedRewards(), _amount / 100);
        assertEq(gauge.periodFinish(), finish);
        skip(10);

        // If more than 120% of what has been distributed is queued -> make a new period
        hoax(gov);
        gauge.queueNewRewards((_amount * 12) / 10 / 7);
        assertNeq(gauge.periodFinish(), finish);
        assertNeq(finish, gauge.periodFinish());
    }
}

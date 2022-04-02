// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "forge-std/console.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";
import {TestFixture} from "./utils/TestFixture.sol";
import "./NextVe.sol";

contract VeTest is TestFixture {

    address public alice = address(10);
    address public bob = address(11);

    uint256 public constant MAX_LOCK_TIME = 4 * 365 * 86400; // 4 years
    uint256 public constant DELTA = 10**7;
    uint256 public constant MULTIPLIER = 10**18;
    uint256 public constant MIN_FUZZ_RANGE = 10 * 10**18;
    uint256 public constant MAX_FUZZ_RANGE = 1000 * 10**22;
    

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

    // function calcPenaltyRatio(uint256 _lockEnd) internal returns (uint256 _penaltyRatio) {
    //     assertGt(_lockEnd, block.timestamp, "expect lockEnd to be bigger than now");
    //     console.log("_lockEnd", _lockEnd);
    //     console.log("block.timestamp", block.timestamp);
    //     uint256 timeLeft = _lockEnd - block.timestamp;
    //     console.log("timeLeft", timeLeft);
    //     uint256 _penaltyRatio = Math.min(MULTIPLIER * 3 / 4,  MULTIPLIER * timeLeft / MAX_LOCK_TIME);
    //     console.log("penaltyRatio", _penaltyRatio);
    // }

    // function calcPenaltyAmount(uint256 _lockedAmount, uint256 _lockEnd) internal returns (uint256 amount) {
    //     uint256 amount = _lockedAmount * calcPenaltyRatio(_lockEnd) / MULTIPLIER;
    //     return amount;
    // }

    function testSetupVeOK() public {
        console.log("address of veYFI", address(veYFI));
        console.log("address of YFI", address(yfi));
        assertEq(veYFI.admin(), gov);
        assertEq(veYFI.token(), address(yfi));
        assertNeq(address(0), address(yfi));
        assertNeq(address(0), address(veYFI));
        assertEq(yfi.balanceOf(whale), WHALE_AMOUNT);
        assertEq(yfi.balanceOf(shark), SHARK_AMOUNT);
        assertEq(yfi.balanceOf(shark), SHARK_AMOUNT);
    }

    /**

    Test voting power in the following scenario.
    Alice:
    ~~~~~~~
    ^
    | *       *
    | | \     |  \
    | |  \    |    \
    +-+---+---+------+---> t
    Bob:
    ~~~~~~~
    ^
    |         *
    |         | \
    |         |  \
    +-+---+---+---+--+---> t
    Alice has 100% of voting power in the first period.
    She has 2/3 power at the start of 2nd period, with Bob having 1/2 power
    (due to smaller locktime).
    Alice's power grows to 100% by Bob's unlock.
    Checking that totalSupply is appropriate.
    After the test is done, check all over again with balanceOfAt / totalSupplyAt
     */
    function testVotingPowers(uint256 _amount) public {
        vm_std_cheats.assume(_amount >= MIN_FUZZ_RANGE && _amount <= MAX_FUZZ_RANGE);

        setupAccountsAandB(_amount);

        assertEq(veYFI.totalSupply(), 0);
        assertEq(veYFI.balanceOf(alice), 0); 
        assertEq(veYFI.balanceOf(bob), 0);

        skipTimeToBeginNextWeek();
        skip(1 hours);
        
        lockYfiFor(_amount, 1 weeks, alice);

        skip(1 hours);

        // dev note: MAX_LOCK_TIME calcs from curve ve testing
        assertEq(veYFI.totalSupply(), _amount / MAX_LOCK_TIME * (1 weeks - 2 * 1 hours));
        assertEq(veYFI.balanceOf(alice), _amount / MAX_LOCK_TIME * (1 weeks - 2 * 1 hours));
        assertEq(veYFI.balanceOf(bob), 0);
        
        uint256 t0 = block.timestamp;

        for (uint8 i = 0; i < 7; i++) {
            skip(24 hours);
            uint256 dt = block.timestamp - t0;
            uint diff = 0;
            if ((1 weeks - 2 * 1 hours) > dt) {
                diff = 1 weeks - 2 * 1 hours - dt;
            }
            assertEq(veYFI.totalSupply(), _amount / MAX_LOCK_TIME * diff);
            assertEq(veYFI.balanceOf(alice), _amount / MAX_LOCK_TIME * diff);
            assertEq(veYFI.balanceOf(bob), 0);
        }

        skip(1 hours);

        assertEq(veYFI.balanceOf(alice), 0);
        hoax(alice);
        veYFI.withdraw();
        assertEq(veYFI.totalSupply(), 0);
        assertEq(veYFI.balanceOf(alice), 0);
        assertEq(veYFI.balanceOf(bob), 0);

        skip(1 hours);

        skipTimeToBeginNextWeek();

        lockYfiFor(_amount, 2 weeks, alice);

        assertEq(veYFI.totalSupply(), _amount / MAX_LOCK_TIME * 2 weeks);
        assertEq(veYFI.balanceOf(alice), _amount / MAX_LOCK_TIME * 2 weeks);
        assertEq(veYFI.balanceOf(bob), 0);

        lockYfiFor(_amount, 1 weeks, bob);

        assertEq(veYFI.totalSupply(), _amount / MAX_LOCK_TIME * 3 weeks);
        assertEq(veYFI.balanceOf(alice), _amount / MAX_LOCK_TIME * 2 weeks);
        assertEq(veYFI.balanceOf(bob),  _amount / MAX_LOCK_TIME * 1 weeks);

        t0 = block.timestamp;

        // Beginning of week: weight 3
        // End of week: weight 
        for (uint8 i = 0; i < 7; i++) {
            skip(24 hours);
            uint256 dt = block.timestamp - t0;
            uint256 wTotal = veYFI.totalSupply();
            uint256 wAlice = veYFI.balanceOf(alice);
            uint256 wBob = veYFI.balanceOf(bob);
            uint256 diff = 0;
            uint256 diff2 = 0;
            if ((2 weeks) > dt) {
                diff = 2 weeks - dt;
            }

            if ((1 weeks) > dt) {
                diff2 = 1 weeks - dt;
            }
            assertEq(wTotal, wAlice + wBob);
            assertEq(wAlice, _amount / MAX_LOCK_TIME * diff);
            assertEq(wBob, _amount / MAX_LOCK_TIME * diff2);
        }
    }

    function testEarlyExit(uint256 _amount) public {
        // setup
        vm_std_cheats.assume(_amount >= MIN_FUZZ_RANGE && _amount <= MAX_FUZZ_RANGE);
        setupAccountsAandB(_amount);

        skipTimeToBeginNextWeek();

        skip(1 hours);
        uint256 bobBalanceBefore = yfi.balanceOf(bob);

        lockYfiFor(_amount, 2 weeks, alice);
        lockYfiFor(_amount, 1 weeks, bob);

        // execution
        hoax(bob);
        veYFI.force_withdraw();
        uint256 bobBalanceAfter = yfi.balanceOf(bob);

        // asserts
        assertEq(veYFI.totalSupply(), veYFI.balanceOf(alice));
        assertGt(bobBalanceBefore, bobBalanceAfter);

        assertEq(bobBalanceAfter, _amount - veYFI.queuedPenalty());
        assertEq(veYFI.queuedPenalty(), bobBalanceBefore - bobBalanceAfter);
    }

    function testMigrateSetBalanceToZero(uint256 _amount) public {
        // setup
        vm_std_cheats.assume(_amount >= MIN_FUZZ_RANGE && _amount <= MAX_FUZZ_RANGE);
        setupAccountsAandB(_amount);

        skipTimeToBeginNextWeek();
        skip(1 hours);

        lockYfiFor(_amount, 2 weeks, alice);
        lockYfiFor(_amount, 1 weeks, bob);

        // execution
        hoax(gov);
        NextVe nextVe = new NextVe(address(yfi));
        hoax(gov);
        veYFI.set_next_ve_contract(address(nextVe));

        //asserts
        assertEq(veYFI.totalSupply(), 0);
        assertEq(veYFI.balanceOf(alice), 0);
        assertEq(veYFI.balanceOf(bob), 0);
    }

    function testCreateLockFor(uint256 _amount) public {
        // setup
        vm_std_cheats.assume(_amount >= MIN_FUZZ_RANGE && _amount <= MAX_FUZZ_RANGE);
        setupAccounts(_amount, gov, panda);

        skipTimeToBeginNextWeek();
        skip(1 hours);

        // execution
        hoax(panda);
        vm_std_cheats.expectRevert();
        veYFI.create_lock_for(doggie, _amount, block.timestamp + 2 weeks);
        hoax(gov);
        veYFI.create_lock_for(doggie, _amount, block.timestamp + 2 weeks);
        // "Withdraw old tokens first" 
        vm_std_cheats.expectRevert();
        veYFI.create_lock_for(doggie, _amount, block.timestamp + 2 weeks);
    }

    function testMigrateLock(uint256 _amount) public {
        // setup
        vm_std_cheats.assume(_amount >= MIN_FUZZ_RANGE && _amount <= MAX_FUZZ_RANGE);
        setupAccounts(_amount, gov, panda);

        skipTimeToBeginNextWeek();
        skip(1 hours);
        lockYfiFor(_amount, 2 weeks, panda);
        // deploy and migrate new Ve contract
        hoax(gov);
        NextVe nextVe = new NextVe(address(yfi));
        hoax(gov);
        veYFI.set_next_ve_contract(address(nextVe));

        // execution
        hoax(panda);
        veYFI.migrate();    

        // assertions
        assertEq(veYFI.balanceOf(panda), 0);
        assertEq(yfi.balanceOf(address(nextVe)), _amount);
    }

}
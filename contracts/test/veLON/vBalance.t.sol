// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "contracts/test/veLON/Setup.t.sol";

contract TestVeLONBalance is TestVeLON {
    using SafeMath for uint256;
    using BalanceSnapshot for BalanceSnapshot.Snapshot;

    function testCreateLockTwoUsesSameBlock() public {
        uint256 total = 0;

        uint256 bobStakeAmount = 15 * 365 days;
        uint256 bobTokenId = _stakeAndValidate(bob, bobStakeAmount, 1 weeks);
        uint256 expectedBobInitvBal = 15 * 7 days;
        assertEq(veLon.vBalanceOf(bobTokenId), expectedBobInitvBal);
        total = total.add(expectedBobInitvBal);
        assertEq(veLon.totalvBalance(), total);

        uint256 aliceStakeAmount = 31 * 365 days;
        uint256 aliceTokenId = _stakeAndValidate(alice, aliceStakeAmount, 3 weeks);
        uint256 expectedAliceInitvBal = 31 * 3 weeks;
        assertEq(veLon.vBalanceOf(aliceTokenId), expectedAliceInitvBal);
        total = total.add(expectedAliceInitvBal);
        assertEq(veLon.totalvBalance(), total);

        // check epoch index
        assertEq(veLon.epoch(), 2);
        assertEq(veLon.userPointEpoch(bobTokenId), 1);
        assertEq(veLon.userPointEpoch(aliceTokenId), 1);
    }

    function testCreateLockTwoUsersDifferentBlock() public {
        uint256 total = 0;

        uint256 bobStakeAmount = 15 * 365 days;
        uint256 bobTokenId = _stakeAndValidate(bob, bobStakeAmount, 1 weeks);
        uint256 expectedBobInitvBal = 15 * 7 days;
        assertEq(veLon.vBalanceOf(bobTokenId), expectedBobInitvBal);
        total = total.add(expectedBobInitvBal);
        assertEq(veLon.totalvBalance(), total);

        // fastforward 1 day
        uint256 dt = 1 days;
        vm.warp(block.timestamp + dt);
        vm.roll(block.number + 1);

        // calculate bob's current vBalance
        uint256 bobBalance = expectedBobInitvBal.sub(dt * 15);
        total = total.sub(dt * 15);

        uint256 aliceStakeAmount = 31 * 365 days;
        uint256 aliceTokenId = _stakeAndValidate(alice, aliceStakeAmount, 1 weeks);
        // after rounding, end - start = 6 days
        uint256 expectedAliceInitvBal = 31 * 6 days;
        assertEq(veLon.vBalanceOf(aliceTokenId), expectedAliceInitvBal);
        total = total.add(expectedAliceInitvBal);
        assertEq(veLon.totalvBalance(), total);

        // check epoch index
        assertEq(veLon.epoch(), 2);
        assertEq(veLon.userPointEpoch(bobTokenId), 1);
        assertEq(veLon.userPointEpoch(aliceTokenId), 1);
    }

    function testCreateLock_and_Withdraw_DifferentTime() public {
        // alice and bob despoit for different amount and time
        uint256 totalBalance = 0;
        uint256 aliceStakeAmount = 1 * 365 days;
        uint256 aliceTokenId = _stakeAndValidate(alice, aliceStakeAmount, 2 weeks);
        uint256 aliceBalance = _initialvBalance(aliceStakeAmount, 2 weeks);
        totalBalance = totalBalance.add(aliceBalance);
        assertEq(veLon.vBalanceOf(aliceTokenId), aliceBalance);
        assertEq(veLon.totalvBalance(), totalBalance);

        uint256 bobStakeAmount = 5 * 365 days;
        uint256 bobTokenId = _stakeAndValidate(bob, bobStakeAmount, 1 weeks);
        uint256 bobBalance = _initialvBalance(bobStakeAmount, 1 weeks);
        totalBalance = totalBalance.add(bobBalance);
        assertEq(veLon.vBalanceOf(bobTokenId), bobBalance);
        assertEq(veLon.totalvBalance(), totalBalance);

        // check the totalSupply
        assertEq(veLon.totalSupply(), 2);

        // fast forward 1 weeks, bob's lock is expired
        uint256 dt = 1 days;
        vm.warp(block.timestamp + 7 * dt);
        vm.roll(block.number + 1);
        // sub Bob's all balance
        totalBalance = totalBalance.sub(bobBalance);
        // sub Alice's delined balance ()
        totalBalance = totalBalance.sub((1 * 7 days));

        // alice's balance
        uint256 expectedAliceBalance = 1 weeks;
        assertEq(veLon.vBalanceOf(aliceTokenId), expectedAliceBalance, "Alice's balance is not as expected");

        // bob's balance
        // bob's lock has ended so the balance is 0
        uint256 expectedBobBalance = 0;
        assertEq(veLon.vBalanceOf(bobTokenId), expectedBobBalance);

        assertEq(veLon.totalvBalance(), totalBalance);
    }

    function testCreateLock_and_OneEarlyWithdraw() public {
        // alice and bob despoit for same amount and time
        uint256 totalBalance = 0;
        uint256 aliceStakeAmount = 5 * 365 days;
        uint256 aliceTokenId = _stakeAndValidate(alice, aliceStakeAmount, 2 weeks);
        uint256 aliceBalance = _initialvBalance(aliceStakeAmount, 2 weeks);
        totalBalance = totalBalance.add(aliceBalance);
        assertEq(veLon.vBalanceOf(aliceTokenId), aliceBalance);
        assertEq(veLon.totalvBalance(), totalBalance);

        uint256 bobStakeAmount = 5 * 365 days;
        uint256 bobTokenId = _stakeAndValidate(bob, bobStakeAmount, 2 weeks);
        uint256 bobBalance = _initialvBalance(bobStakeAmount, 2 weeks);
        totalBalance = totalBalance.add(bobBalance);
        assertEq(veLon.vBalanceOf(bobTokenId), bobBalance);
        assertEq(veLon.totalvBalance(), totalBalance);

        // fast forward 1 week
        vm.warp(block.timestamp + 1 weeks);

        // Alice early withdraw 1 week beforehand,
        // calculate the balacence for alice and bob respectively
        uint256 aliceDeclineBalance = aliceBalance;
        uint256 bobDeclineBalance = 5 * 1 weeks;
        totalBalance = totalBalance.sub(aliceDeclineBalance + bobDeclineBalance);
        vm.prank(alice);
        veLon.withdrawEarly(aliceTokenId);
        assertEq(veLon.totalvBalance(), totalBalance, "totalBalance not equal");

        // check epoch index
        assertEq(veLon.epoch(), 3);
        assertEq(veLon.userPointEpoch(bobTokenId), 1);
        assertEq(veLon.userPointEpoch(aliceTokenId), 2);
    }

    /*****************************************
     *   Uint Test for balance of single Ve  *
     *****************************************/
    function testVbalanceOf() public {
        uint256 tokenId = _stakeAndValidate(user, DEFAULT_STAKE_AMOUNT, 2 weeks);
        uint256 vBalance = veLon.vBalanceOf(tokenId);
        uint256 expectBalance = 10 * 2 weeks;
        assertEq(vBalance, expectBalance, "Balance is not equal");

        // fast forward 1 week
        vm.warp(block.timestamp + 1 weeks);
        expectBalance = 10 * 1 weeks;
        vBalance = veLon.vBalanceOf(tokenId);
        assertEq(vBalance, expectBalance);
    }

    function testVBalanceOfAtTime() public {
        uint256 aliceStakeAmount = 10 * 365 days;
        uint256 aliceTokenId = _stakeAndValidate(alice, aliceStakeAmount, 2 weeks);

        // fast forward 1 week
        vm.warp(block.timestamp + 1 weeks);
        vm.roll(block.number + 1);

        // calculate Alice's balance
        // declineRate  = locking_amount / MAX_lock_duration = (10 * 365 days)/ 365days = 10
        // exptectedBalance = initial balance - decline balance = 10 * 2 weeks - 10 * 1 weeks = 10 * 1 week
        uint256 expectAliceBalance = 10 * 7 days;
        assertEq(veLon.vBalanceOfAtTime(aliceTokenId, block.timestamp), expectAliceBalance);
    }

    function testCannotGetVBalabnceInFuture() public {
        uint256 tokenId = _stakeAndValidate(user, DEFAULT_STAKE_AMOUNT, DEFAULT_LOCK_TIME);
        vm.expectRevert("Invalid timestamp");
        veLon.vBalanceOfAtTime(tokenId, block.timestamp + 1 weeks);
    }

    function testVBalanceOfAtBlk() public {
        uint256 tokenId = _stakeAndValidate(user, DEFAULT_STAKE_AMOUNT, DEFAULT_LOCK_TIME);

        // next block and 1 week later
        uint256 expectBalance = 10 * 1 weeks;
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1 weeks);
        assertEq(veLon.vBalanceOfAtBlk(tokenId, block.number), expectBalance);
    }

    // test testVBalanceOfAtBlk() when target block != current block
    function testVBalanceOfAtBlkPast() public {
        uint256 tokenId = _stakeAndValidate(user, DEFAULT_STAKE_AMOUNT, 2 weeks);
        uint256 initialBalacne = _initialvBalance(DEFAULT_STAKE_AMOUNT, 2 weeks);

        // Assume current block.number is 0, then fast forward to 10 blocks and 2 weeks later,
        // but query the 5th block at the beginning of second week (1 weeks later)
        uint256 dBlock = 1;
        uint256 dt = 1 days;
        uint256 targetBlock = (block.number + 5);
        vm.roll(block.number + 10 * dBlock);
        vm.warp(block.timestamp + 14 * dt);

        uint256 expectedBalance = initialBalacne - 10 * 7 * dt;
        assertEq(veLon.vBalanceOfAtBlk(tokenId, targetBlock), expectedBalance);
    }

    // test vBalanceOfAtBlk() when the target block is before lastPoint.blk
    function testVBalanceOfAtBlkBeforeLastPoint() public {
        uint256 aliceTokenId = _stakeAndValidate(user, DEFAULT_STAKE_AMOUNT, 2 weeks);
        uint256 aliceBalance = _initialvBalance(DEFAULT_STAKE_AMOUNT, 2 weeks);

        assertEq(veLon.epoch(), 1);
        assertEq(veLon.vBalanceOfAtBlk(aliceTokenId, block.number), aliceBalance);

        // fast forward 1 week and second user createlock
        vm.warp(block.timestamp + 1 weeks);
        vm.roll(block.number + 1);
        uint256 bobTokenId = _stakeAndValidate(bob, DEFAULT_STAKE_AMOUNT, 2 weeks);
        uint256 bobBalance = _initialvBalance(DEFAULT_STAKE_AMOUNT, 2 weeks);

        // verify the vBalanceOfAtblk of 1st block when Alcie createLock
        assertEq(veLon.vBalanceOfAtBlk(aliceTokenId, block.number - 1), aliceBalance);

        // Continue fast forward 1 week
        // Bob extend lock for 2 weeks
        vm.warp(block.timestamp + 1 weeks);
        vm.roll(block.number + 1);
        vm.prank(bob);
        veLon.extendLock(bobTokenId, 2 weeks);

        // Verify the vBalanceOfAtBlk when first block Alice createLock
        assertEq(veLon.vBalanceOfAtBlk(aliceTokenId, block.number - 2), aliceBalance);
    }

    // test vBalanceOfAtTime() when the target _t is before lastPoint.ts
    function testVBalanceOfAtTimeBeforeLastPoint() public {
        uint256 tokenId = _stakeAndValidate(user, DEFAULT_STAKE_AMOUNT, 2 weeks);
        uint256 expectedBalance = _initialvBalance(DEFAULT_STAKE_AMOUNT, 2 weeks);

        assertEq(veLon.userPointEpoch(1), 1);
        assertEq(veLon.vBalanceOfAtTime(tokenId, block.timestamp), expectedBalance);

        // fast forward 1 weeks and user extend lock for 3 weeks, so the the vBalance is 2 week more
        // The userEpoch should be 2 (createLock, extendLock)
        // And the lastPoint of user should be updated now becase user extendedLock
        vm.warp(block.timestamp + 1 weeks);
        vm.roll(block.number + 1);
        vm.prank(user);
        veLon.extendLock(tokenId, 3 weeks);

        // expetedBalance  = initialBalance - 1 weeks passed + 2 week extended
        assertEq(veLon.userPointEpoch(tokenId), 2);
        expectedBalance = (expectedBalance - (10 * 1 weeks) + (10 * 2 weeks));
        assertEq(veLon.vBalanceOf(tokenId), expectedBalance);
        assertEq(veLon.userPointEpoch(tokenId), 2);

        // Continue fast forward 1 week, so now is the third week(2 weeks passed since createLock)
        // Query the vBalanceOfAtime in first week (the time lock was created)
        // The traget time is before lastPoint.ts(the time lock was extended)
        vm.warp(block.timestamp + 1 weeks);
        vm.roll(block.number + 1);
        uint256 initialBalance = _initialvBalance(DEFAULT_STAKE_AMOUNT, 2 weeks);
        assertEq(veLon.userPointEpoch(tokenId), 2);
        assertEq(veLon.vBalanceOfAtTime(tokenId, block.timestamp - 2 weeks), initialBalance);

        // Fast forward 1 week
        // ExtendLock in forth week(3 weeks passed), and query the first week(creatLock)
        vm.warp(block.timestamp + 1 weeks);
        vm.roll(block.number + 1);
        vm.prank(user);
        veLon.extendLock(tokenId, 2 weeks);
        assertEq(veLon.userPointEpoch(tokenId), 3);
        assertEq(veLon.vBalanceOfAtTime(tokenId, block.timestamp - 3 weeks), initialBalance);
    }

    function testCannotGetVBalabnceAtFutureBlk() public {
        uint256 tokenId = _stakeAndValidate(user, DEFAULT_STAKE_AMOUNT, 2 weeks);
        vm.expectRevert("Invalid block number");
        // get balance in future block
        veLon.vBalanceOfAtBlk(tokenId, block.number + 1);
    }

    /***********************************
     *   Uint Test for Total Balance *
     ***********************************/
    function testTotalvBalance() public {
        _stakeAndValidate(alice, DEFAULT_STAKE_AMOUNT, 2 weeks);
        _stakeAndValidate(bob, DEFAULT_STAKE_AMOUNT, 2 weeks);
        uint256 totalvBalance = veLon.totalvBalance();
        uint256 expectvBalance = _initialvBalance(2 * DEFAULT_STAKE_AMOUNT, 2 weeks);
        assertEq(totalvBalance, expectvBalance);
    }

    function testTotalvBalanceAtTime() public {
        _stakeAndValidate(user, DEFAULT_STAKE_AMOUNT, 2 weeks);
        uint256 totalvBalance = veLon.totalvBalanceAtTime(block.timestamp);
        uint256 expectvBalance = 10 * 2 weeks;
        assertEq(totalvBalance, expectvBalance);

        // test 1 week has passed
        vm.warp(block.timestamp + 1 weeks);
        vm.roll(block.number + 1);
        totalvBalance = veLon.totalvBalanceAtTime(block.timestamp);
        expectvBalance = 10 * 1 weeks;
        assertEq(totalvBalance, expectvBalance);
    }

    function testCannotGetTotalvBalanceInFuture() public {
        vm.expectRevert("Invalid timestamp");
        veLon.totalvBalanceAtTime(block.timestamp + 1 weeks);
    }

    function testTotalvBalanceAtBlk() public {
        _stakeAndValidate(user, DEFAULT_STAKE_AMOUNT, 2 weeks);
        uint256 totalvBalance = veLon.totalvBalanceAtBlk(block.number);
        uint256 expectvBalance = 10 * 2 weeks;
        assertEq(totalvBalance, expectvBalance);

        // 10 blocks and 1 week has passed
        expectvBalance = 10 * 1 weeks;
        vm.roll(block.number + 10);
        vm.warp(block.timestamp + 1 weeks);
        assertEq(veLon.totalvBalanceAtBlk(block.number), expectvBalance);
    }

    function testCannotGetTotalvBalanceAtFutureBlk() public {
        vm.expectRevert("Invalid block number");
        veLon.totalvBalanceAtBlk(block.number + 1);
    }

    // test totalVbalanceAtBlk when target block != current block
    function testTotalVBalanceAtBlkPast() public {
        // alice and bob despoit for same amount and same time
        uint256 totalBalance = 0;
        uint256 aliceStakeAmount = 10 * 365 days;
        uint256 aliceTokenId = _stakeAndValidate(alice, aliceStakeAmount, 2 weeks);
        uint256 aliceBalance = _initialvBalance(aliceStakeAmount, 2 weeks);
        totalBalance = totalBalance.add(aliceBalance);
        assertEq(veLon.vBalanceOf(aliceTokenId), aliceBalance);
        assertEq(veLon.totalvBalance(), totalBalance);

        uint256 bobStakeAmount = 10 * 365 days;
        uint256 bobTokenId = _stakeAndValidate(bob, bobStakeAmount, 2 weeks);
        uint256 bobBalance = _initialvBalance(bobStakeAmount, 2 weeks);
        totalBalance = totalBalance.add(bobBalance);
        assertEq(veLon.vBalanceOf(bobTokenId), bobBalance);
        assertEq(veLon.totalvBalance(), totalBalance);

        // Assume current block.number is 0, then fast forward to 10 blocks and 2 weeks later,
        // but query the 5th block at the beginning of second week (1 weeks later)
        uint256 dBlock = 1;
        uint256 dt = 1 days;
        uint256 targetBlock = (block.number + 5);
        vm.roll(block.number + 10 * dBlock);
        vm.warp(block.timestamp + 14 * dt);

        // total balance -= (Alice_DeclineRate * 7 days + Bob_DeclineRate * 7 days)
        totalBalance = totalBalance - (2 * 10 * 7 * dt);
        assertEq(veLon.totalvBalanceAtBlk(targetBlock), totalBalance);
    }

    // test vBalanceOfAtTime() when the target _t is before lastPoint.ts
    function testTotalVBalanceAtTimeBeforeLastPoint() public {
        uint256 aliceTokenId = _stakeAndValidate(alice, DEFAULT_STAKE_AMOUNT, 2 weeks);
        uint256 aliceBalance = _initialvBalance(DEFAULT_STAKE_AMOUNT, 2 weeks);

        assertEq(veLon.epoch(), 1);
        assertEq(veLon.totalvBalanceAtTime(block.timestamp), aliceBalance);

        // fast forward 1 week and second user createlock
        vm.warp(block.timestamp + 1 weeks);
        vm.roll(block.number + 1);
        uint256 bobTokenId = _stakeAndValidate(bob, DEFAULT_STAKE_AMOUNT, 3 weeks);
        uint256 bobBalance = _initialvBalance(DEFAULT_STAKE_AMOUNT, 2 weeks);

        // verify the totalBalance of 1st week when Alcie createLock
        assertEq(veLon.totalvBalanceAtTime(block.timestamp - 1 weeks), aliceBalance);

        // Continue fast forward 2 week
        // Bob extend lock for 2 weeks
        vm.warp(block.timestamp + 2 weeks);
        vm.roll(block.number + 1);
        vm.prank(bob);
        veLon.extendLock(bobTokenId, 2 weeks);

        // Query the totalvBalance of third week when Alice's lock has expired
        // and Bob's lock has passed 1 week
        uint256 totalBalance = bobBalance - 10 * 1 weeks;
        assertEq(veLon.totalvBalanceAtTime(block.timestamp - 2 weeks), totalBalance);
    }

    // test totalVBalanceAtBlk() when the target block is before lastPoint.blk
    function testTotalVBalanceAtBlkBeforeLastPoint() public {
        uint256 aliceTokenId = _stakeAndValidate(alice, DEFAULT_STAKE_AMOUNT, 2 weeks);
        uint256 aliceBalance = _initialvBalance(DEFAULT_STAKE_AMOUNT, 2 weeks);

        assertEq(veLon.epoch(), 1);
        assertEq(veLon.totalvBalanceAtBlk(block.number), aliceBalance);

        // fast forward 1 week and second user createlock
        vm.warp(block.timestamp + 1 weeks);
        vm.roll(block.number + 1);
        uint256 bobTokenId = _stakeAndValidate(bob, DEFAULT_STAKE_AMOUNT, 2 weeks);
        uint256 bobBalance = _initialvBalance(DEFAULT_STAKE_AMOUNT, 2 weeks);

        // verify the totalBalance of 1st week when Alcie createLock
        assertEq(veLon.totalvBalanceAtBlk(block.number - 1), aliceBalance);

        // Continue fast forward 1 week
        // Bob extend lock for 2 weeks
        vm.warp(block.timestamp + 1 weeks);
        vm.roll(block.number + 1);
        vm.prank(bob);
        veLon.extendLock(bobTokenId, 2 weeks);

        // Verify the totalvBalanceAtBlk when first week Alice createLock
        assertEq(veLon.totalvBalanceAtBlk(block.number - 2), aliceBalance);
    }
}

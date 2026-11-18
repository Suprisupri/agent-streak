// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AgentStreak.sol";

/// @notice Minimal mock of the SPACE ID Agent ID contract (ERC-721).
/// @dev Only balanceOf() matters for AgentStreak; balances are settable.
contract MockAgentId {
    mapping(address => uint256) private _balances;

    function setBalance(address account, uint256 amount) external {
        _balances[account] = amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
}

contract AgentStreakTest is Test {
    AgentStreak public streak;
    MockAgentId public agentId;

    address public owner = address(this);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    uint256 public constant DAY = 86400;
    // Start at a clean UTC day boundary to make day math obvious.
    uint256 public constant START = 100 * DAY;

    function setUp() public {
        agentId = new MockAgentId();
        streak = new AgentStreak(address(agentId), owner);
        agentId.setBalance(alice, 1);
        agentId.setBalance(bob, 1);
        vm.warp(START);
    }

    // ------------------------------------------------------------------------
    // Gating
    // ------------------------------------------------------------------------
    function test_RevertWhen_NoAgentId() public {
        address stranger = address(0x999);
        vm.prank(stranger);
        vm.expectRevert(AgentStreak.NotAgentIdHolder.selector);
        streak.checkIn();
    }

    function test_CheckIn_SucceedsWithAgentId() public {
        vm.prank(alice);
        streak.checkIn();
        assertEq(streak.currentStreak(alice), 1);
        assertEq(streak.bestStreak(alice), 1);
        assertEq(streak.totalCheckIns(alice), 1);
        assertEq(streak.totalUsers(), 1);
        assertEq(streak.totalCheckInsGlobal(), 1);
    }

    // ------------------------------------------------------------------------
    // One check-in per day
    // ------------------------------------------------------------------------
    function test_RevertWhen_CheckInTwiceSameDay() public {
        vm.prank(alice);
        streak.checkIn();
        vm.warp(START + 12 hours); // same UTC day
        vm.prank(alice);
        vm.expectRevert(AgentStreak.AlreadyCheckedIn.selector);
        streak.checkIn();
    }

    function test_CheckIn_NextDaySucceeds() public {
        vm.prank(alice);
        streak.checkIn();
        vm.warp(START + DAY);
        vm.prank(alice);
        streak.checkIn();
        assertEq(streak.currentStreak(alice), 2);
    }

    // ------------------------------------------------------------------------
    // Streak math
    // ------------------------------------------------------------------------
    function test_Streak_ThreeConsecutiveDays() public {
        for (uint256 i = 0; i < 3; i++) {
            vm.warp(START + i * DAY);
            vm.prank(alice);
            streak.checkIn();
        }
        assertEq(streak.currentStreak(alice), 3);
        assertEq(streak.bestStreak(alice), 3);
        assertEq(streak.totalCheckIns(alice), 3);
    }

    function test_Streak_ResetsAfterGap_BestStreakKept() public {
        for (uint256 i = 0; i < 3; i++) {
            vm.warp(START + i * DAY);
            vm.prank(alice);
            streak.checkIn();
        }
        // Skip one full day, then check in again.
        vm.warp(START + 4 * DAY);
        vm.prank(alice);
        streak.checkIn();
        assertEq(streak.currentStreak(alice), 1, "streak resets to 1 after a gap");
        assertEq(streak.bestStreak(alice), 3, "bestStreak keeps the old record");
        assertEq(streak.totalCheckIns(alice), 4);
    }

    function test_Streak_EventEmitted() public {
        vm.expectEmit(true, false, false, true);
        emit AgentStreak.CheckedIn(alice, START / DAY, 1);
        vm.prank(alice);
        streak.checkIn();
    }

    // ------------------------------------------------------------------------
    // Badges
    // ------------------------------------------------------------------------
    function _streakDays(address user, uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            vm.warp(START + i * DAY);
            vm.prank(user);
            streak.checkIn();
        }
    }

    function test_RevertWhen_ClaimBadgeBeforeStreak7() public {
        _streakDays(alice, 6);
        vm.prank(alice);
        vm.expectRevert(AgentStreak.InsufficientStreak.selector);
        streak.claimBadge(7);
    }

    function test_ClaimBadge_AfterStreak7() public {
        _streakDays(alice, 7);
        vm.prank(alice);
        uint256 tokenId = streak.claimBadge(7);
        assertEq(tokenId, 1);
        assertTrue(streak.hasBadge(alice, 7));
        assertEq(streak.balanceOf(alice), 1);
        assertEq(streak.ownerOf(1), alice);
        assertEq(streak.badgeMilestone(1), 7);
    }

    function test_RevertWhen_ClaimBadgeTwiceSameMilestone() public {
        _streakDays(alice, 7);
        vm.prank(alice);
        streak.claimBadge(7);
        vm.prank(alice);
        vm.expectRevert(AgentStreak.BadgeAlreadyClaimed.selector);
        streak.claimBadge(7);
    }

    function test_RevertWhen_InvalidMilestone() public {
        _streakDays(alice, 30);
        vm.prank(alice);
        vm.expectRevert(AgentStreak.InvalidMilestone.selector);
        streak.claimBadge(10);
        vm.prank(alice);
        vm.expectRevert(AgentStreak.InvalidMilestone.selector);
        streak.claimBadge(0);
    }

    function test_ClaimBadge_AllMilestones() public {
        _streakDays(alice, 30);
        vm.startPrank(alice);
        assertEq(streak.claimBadge(7), 1);
        assertEq(streak.claimBadge(14), 2);
        assertEq(streak.claimBadge(30), 3);
        vm.stopPrank();
        assertEq(streak.balanceOf(alice), 3);
        assertTrue(streak.hasBadge(alice, 14));
        assertTrue(streak.hasBadge(alice, 30));
    }

    function test_BadgeClaimed_EventEmitted() public {
        _streakDays(alice, 7);
        vm.expectEmit(true, false, false, true);
        emit AgentStreak.BadgeClaimed(alice, 7, 1);
        vm.prank(alice);
        streak.claimBadge(7);
    }

    // ------------------------------------------------------------------------
    // Soulbound
    // ------------------------------------------------------------------------
    function test_RevertWhen_TransferBadge() public {
        _streakDays(alice, 7);
        vm.prank(alice);
        streak.claimBadge(7);

        vm.prank(alice);
        vm.expectRevert(AgentStreak.Soulbound.selector);
        streak.transferFrom(alice, bob, 1);

        vm.prank(alice);
        vm.expectRevert(AgentStreak.Soulbound.selector);
        streak.safeTransferFrom(alice, bob, 1);

        vm.prank(alice);
        vm.expectRevert(AgentStreak.Soulbound.selector);
        streak.safeTransferFrom(alice, bob, 1, "");
    }

    function test_RevertWhen_ApproveBadge() public {
        _streakDays(alice, 7);
        vm.prank(alice);
        streak.claimBadge(7);

        vm.prank(alice);
        vm.expectRevert(AgentStreak.Soulbound.selector);
        streak.approve(bob, 1);

        vm.prank(alice);
        vm.expectRevert(AgentStreak.Soulbound.selector);
        streak.setApprovalForAll(bob, true);
    }

    // ------------------------------------------------------------------------
    // Metadata
    // ------------------------------------------------------------------------
    function test_TokenURI_ReturnsDataUri() public {
        _streakDays(alice, 7);
        vm.prank(alice);
        streak.claimBadge(7);
        string memory uri = streak.tokenURI(1);
        // Must be a base64 JSON data URI.
        bytes memory prefix = bytes("data:application/json;base64,");
        bytes memory uriBytes = bytes(uri);
        assertGt(uriBytes.length, prefix.length);
        for (uint256 i = 0; i < prefix.length; i++) {
            assertEq(uriBytes[i], prefix[i], "tokenURI must start with data:application/json;base64,");
        }
    }

    function test_RevertWhen_TokenURINonexistent() public {
        vm.expectRevert(AgentStreak.TokenDoesNotExist.selector);
        streak.tokenURI(999);
    }

    // ------------------------------------------------------------------------
    // Pause
    // ------------------------------------------------------------------------
    function test_Pause_Unpause_ByOwner() public {
        streak.pause();
        assertTrue(streak.paused());
        streak.unpause();
        assertFalse(streak.paused());
    }

    function test_RevertWhen_CheckInWhilePaused() public {
        streak.pause();
        vm.prank(alice);
        vm.expectRevert(AgentStreak.ContractPaused.selector);
        streak.checkIn();
    }

    function test_RevertWhen_ClaimBadgeWhilePaused() public {
        _streakDays(alice, 7);
        streak.pause();
        vm.prank(alice);
        vm.expectRevert(AgentStreak.ContractPaused.selector);
        streak.claimBadge(7);
    }

    function test_RevertWhen_NonOwnerPause() public {
        vm.prank(alice);
        vm.expectRevert(AgentStreak.NotOwner.selector);
        streak.pause();
    }

    function test_RevertWhen_NonOwnerUnpause() public {
        streak.pause();
        vm.prank(alice);
        vm.expectRevert(AgentStreak.NotOwner.selector);
        streak.unpause();
    }

    // ------------------------------------------------------------------------
    // Global counters
    // ------------------------------------------------------------------------
    function test_TotalUsers_CountsUniqueAddresses() public {
        vm.prank(alice);
        streak.checkIn();
        vm.prank(bob);
        streak.checkIn();
        vm.warp(START + DAY);
        vm.prank(alice);
        streak.checkIn();
        assertEq(streak.totalUsers(), 2, "second check-in by alice must not add a user");
        assertEq(streak.totalCheckInsGlobal(), 3);
    }

    // ------------------------------------------------------------------------
    // No funds accepted
    // ------------------------------------------------------------------------
    function test_RevertWhen_SendBNB() public {
        (bool ok, ) = address(streak).call{value: 1 ether}("");
        assertFalse(ok, "contract must reject incoming BNB");
    }
}

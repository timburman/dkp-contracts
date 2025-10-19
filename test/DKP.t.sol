// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DKP} from "../src/DKP.sol";
import {DKPToken} from "../src/DKPToken.sol";

contract DKPTest is Test {
    address public owner = makeAddr("Owner");
    address public user = makeAddr("user");
    address public voter1 = makeAddr("voter1");
    address public voter2 = makeAddr("voter2");
    DKP public dkp;
    DKPToken public dkpToken;

    event ContentSubmitted(uint256 indexed id, address indexed author);
    event Voted(uint256 indexed id, address indexed user);
    event ReclaimedReputation(uint256 indexed id, address indexed user, uint256 reputationReclaimed);

    function setUp() public {
        dkp = new DKP();
        dkpToken = new DKPToken();

        dkpToken.initialize(owner);
        dkp.initialize(owner, address(dkpToken));

        vm.prank(owner);
        dkp.supplyReputation(user);

        vm.prank(owner);
        dkpToken.mint(address(dkp), 1000 ether);
    }

    function submissionOfContent() public returns (uint256 id) {
        bytes32 _contentHash = keccak256("Lalala");
        vm.prank(user);
        id = dkp.submitContent(_contentHash);
    }

    function voteForReview(uint256 submissionId, bool isUpVote) public {
        uint256 seed = 57;

        for (uint256 i = 0; i < 20; i++) {
            vm.prank(address(uint160(uint256(keccak256(abi.encode(seed, i))))));
            dkp.vote(submissionId, 5, isUpVote);
        }
    }

    function test_IdCounter() public {
        assertEq(dkp.getCurrentId(), 1);

        vm.prank(user);
        dkp.submitContent(keccak256("Lalalal"));

        assertEq(dkp.getCurrentId(), 2);
    }

    function test_SubmitContent(bytes32 _contentHash) public {
        vm.prank(user);
        uint256 id = dkp.submitContent(_contentHash);

        DKP.Submission memory s = dkp.getSubmissions(id);

        assertEq(id, s.id);
        assertEq(_contentHash, s.contentHash);
        assertEq(user, s.author);
        assertEq(dkp.reputationScore(user), 0);
    }

    function test_SubmissionEmit() public {
        vm.prank(user);
        vm.expectEmit(true, true, false, false);
        emit ContentSubmitted(1, user);
        dkp.submitContent(keccak256("Yolo"));
    }

    function test_Voting() public {
        uint256 id = submissionOfContent();

        vm.prank(voter1);
        dkp.vote(id, 5, true);

        vm.prank(voter2);
        dkp.vote(id, 5, true);

        DKP.Submission memory s = dkp.getSubmissions(id);

        assertEq(s.upVotes, 10);
        assertEq(s.downVotes, 0);
    }

    function test_VoteEmit() public {
        uint256 id = submissionOfContent();

        vm.prank(voter1);
        vm.expectEmit(true, true, false, false);
        emit Voted(id, voter1);
        dkp.vote(id, 5, true);
    }

    function test_FailVoteTwice() public {
        uint256 id = submissionOfContent();

        vm.prank(voter1);
        dkp.vote(id, 5, true);

        vm.prank(voter1);
        vm.expectRevert("Already Voted");
        dkp.vote(id, 5, false);
    }

    function test_FailVoteOnNonExistentSubmission(uint256 randomId) public {
        vm.assume(randomId != 1);
        submissionOfContent();

        vm.prank(voter1);
        vm.expectRevert("DKP: Invalid Submission Id");
        dkp.vote(randomId, 5, true);
    }

    function test_minVoteCountForReview(uint256 seed) public {
        uint256 id = submissionOfContent();

        for (uint256 i = 0; i < 20; i++) {
            vm.prank(address(uint160(uint256(keccak256(abi.encode(seed, i))) | 1)));
            dkp.vote(id, 5, true);
        }
        DKP.SubmissionStatus currentStatus = dkp.getSubmissionStatus(id);
        DKP.SubmissionStatus expectedStatus = DKP.SubmissionStatus.InReview;
        assertEq(uint256(currentStatus), uint256(expectedStatus));
    }

    function test_submissionColletralReturned() public {
        uint256 id = submissionOfContent();

        voteForReview(id, true);

        skip(7 days);

        assertEq(uint256(dkp.getSubmissionStatus(id)), uint256(DKP.SubmissionStatus.Verified));

        vm.prank(user);
        dkp.claimRewards(id);
        DKP.Submission memory s = dkp.getSubmissions(id);

        assertEq(s.rewardClaimed, true);

        assertEq(dkpToken.balanceOf(user), 50 ether);
        assertEq(dkp.getReputationScore(user), 50);
    }

    function test_FailClaimRewardsOnDownVote() public {
        uint256 id = submissionOfContent();
        voteForReview(id, false);

        skip(7 days);

        assertEq(uint256(dkp.getSubmissionStatus(id)), uint256(DKP.SubmissionStatus.Rejected));

        vm.prank(user);
        vm.expectRevert("DKP: Submission not verified");
        dkp.claimRewards(id);
    }

    function test_claimReputationBack() public {
        uint256 id = submissionOfContent();
        voteForReview(id, true);

        skip(7 days);

        vm.startPrank(address(uint160(uint256(keccak256(abi.encode(57, 1))))));
        vm.expectEmit();
        emit ReclaimedReputation(id, address(uint160(uint256(keccak256(abi.encode(57, 1))))), 7);
        dkp.reclaimReputation(id);

        vm.expectRevert();
        dkp.reclaimReputation(id);
        vm.stopPrank();
    }

    function test_FailClaimReputationBack() public {
        uint256 id = submissionOfContent();
        voteForReview(id, true);

        vm.prank(voter1);
        dkp.vote(id, 5, false);

        skip(7 days);

        vm.prank(voter1);
        vm.expectRevert();
        dkp.reclaimReputation(id);
    }
}

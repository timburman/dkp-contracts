// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/DKP.sol";

contract DKPTest is Test {
    address public owner = makeAddr("Owner");
    address public user = makeAddr("user");
    address public voter1 = makeAddr("voter1");
    address public voter2 = makeAddr("voter2");
    DKP public dkp;

    event ContentSubmitted(uint256 indexed Id, address indexed author);
    event Voted(uint256 indexed Id, address indexed user);

    function setUp() public {
        dkp = new DKP();

        dkp.initialize(owner);
    }

    function submissionOfContent() public returns (uint256 id) {
        bytes32 _contentHash = keccak256("Lalala");
        vm.prank(user);
        id = dkp.submitContent(_contentHash);
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
        dkp.vote(id, true);

        vm.prank(voter2);
        dkp.vote(id, true);

        DKP.Submission memory s = dkp.getSubmissions(id);

        assertEq(s.upVotes, 2);
        assertEq(s.downVotes, 0);
    }

    function test_VoteEmit() public {
        uint256 id = submissionOfContent();

        vm.prank(voter1);
        vm.expectEmit(true, true, false, false);
        emit Voted(id, voter1);
        dkp.vote(id, true);
    }

    function test_FailVoteTwice() public {
        uint256 id = submissionOfContent();

        vm.prank(voter1);
        dkp.vote(id, true);

        vm.prank(voter1);
        vm.expectRevert("Already Voted");
        dkp.vote(id, false);
    }

    function test_FailVoteOnNonExistentSubmission(uint256 randomId) public {
        vm.assume(randomId != 1);
        submissionOfContent();

        vm.prank(voter1);
        vm.expectRevert("Invalid Submission Id");
        dkp.vote(randomId, true);
    }
}

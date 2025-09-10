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

    function setUp() public {
        dkp = new DKP();

        dkp.initialize(owner);
    }

    function submissionOfContent() public returns (uint256 id) {
        bytes32 _contentHash = bytes32("Lalala");
        vm.prank(user);
        id = dkp.submitContent(_contentHash);
    }

    function testSubmitContent(bytes32 _contentHash) public {
        vm.prank(user);
        uint256 id = dkp.submitContent(_contentHash);

        DKP.Submission memory s = dkp.getSubmissions(id);

        assertEq(id, s.id);
        assertEq(_contentHash, s.contentHash);
        assertEq(user, s.author);
    }

    function testVoting() public {
        uint256 id = submissionOfContent();

        vm.prank(voter1);
        dkp.vote(id, true);

        vm.prank(voter2);
        dkp.vote(id, true);

        DKP.Submission memory s = dkp.getSubmissions(id);

        assertEq(s.upVotes, 2);
        assertEq(s.downVotes, 0);
    }
}

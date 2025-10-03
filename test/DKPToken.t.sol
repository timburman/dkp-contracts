// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import {DKPToken} from  "../src/DKPToken.sol";

contract DKPTokenTest is Test {
    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    DKPToken public dkpToken;

    function setUp() public {

        dkpToken = new DKPToken();
        dkpToken.initialize(owner);

        vm.prank(owner);
        dkpToken.mint(user1, 1000);

        vm.prank(owner);
        dkpToken.mint(user2, 1000);
    }

    function testUserBalances() public {

        assertEq(dkpToken.balanceOf(user1), 1000);
        assertEq(dkpToken.balanceOf(user2), 1000);

        vm.prank(owner);
        dkpToken.mint(user1, 50);

        assertEq(dkpToken.balanceOf(user1), 1050);

    }

    function testUserCannotMint() public {

        vm.prank(user1);
        vm.expectRevert();
        dkpToken.mint(user1, 100000000);


    }
}

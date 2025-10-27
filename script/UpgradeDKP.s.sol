// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DKP} from "../src/DKP.sol";

contract UpgradeDKP is Script {
    address public constant DKP_PROXY_ADDRESS = 0x6789E70ada20C853E12b8bae36085e60FeaAE7Eb;

    function run() external {
        vm.startBroadcast();

        DKP newImplementation = new DKP();
        console.log("New DKP implementation deployed at:", address(newImplementation));

        DKP proxy = DKP(DKP_PROXY_ADDRESS);

        proxy.upgradeToAndCall(address(newImplementation), bytes(""));
        console.log("DKP Proxy has been upgraded");

        if (proxy.minVoteCountForReview() == 0) {
            proxy.setMinVoteCountForReview(100);
            console.log("DKP minVoteCountForReview changed to 100");
        }

        vm.stopBroadcast();
    }
}

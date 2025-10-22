// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DKP} from "../src/DKP.sol";

contract UpgradeDKP is Script {
    address public constant DKP_PROXY_ADDRESS = 0xB4bFc0626aF9D4D4dd5Eb0f69aB51f4bFEab5B98;

    function run() external {
        vm.startBroadcast();

        DKP newImplementation = new DKP();
        console.log("New DKP implementation deployed at:", address(newImplementation));

        DKP proxy = DKP(DKP_PROXY_ADDRESS);

        proxy.upgradeToAndCall(address(newImplementation), bytes(""));
        console.log("DKP proxy has been upgraded");

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DKP} from "../src/DKP.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployDKP is Script {
    function run() external returns (address) {
        address initialOwner = msg.sender;

        vm.startBroadcast();

        DKP implementation = new DKP();
        console.log("Step 1: DKP Implementation deployed to address:", address(implementation));

        bytes memory data = abi.encodeWithSignature("initialize(address)", initialOwner);

        ERC1967Proxy prxy = new ERC1967Proxy(address(implementation), data);
        console.log("Step 2: DKP Proxy Deployed at address:", address(prxy));

        vm.stopBroadcast();

        return address(prxy);
    }
}

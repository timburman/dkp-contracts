// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DKPToken} from "../src/DKPToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployDKPToken is Script {
    function run() external returns (address) {
        address initialOwner = msg.sender;
        vm.startBroadcast();

        DKPToken implementation = new DKPToken();
        console.log("Token implementation deployed at:", address(implementation));

        bytes memory data = abi.encodeWithSignature("initialize(address)", initialOwner);

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        console.log("Token Proxy Deployed at:", address(proxy));

        vm.stopBroadcast();
        return address(proxy);
    }
}

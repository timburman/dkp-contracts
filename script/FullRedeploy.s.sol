// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DKP} from "../src/DKP.sol";
import {DKPToken} from "../src/DKPToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract FullRedeploy is Script {
    function run() external {
        vm.startBroadcast();

        address initialOwner = msg.sender;
        console.log("Deploying all contracts with owner:", initialOwner);

        // -- Token Deployemnt --
        DKPToken tokenImplementation = new DKPToken();
        console.log("DKP Token implementation deployed at:", address(tokenImplementation));

        bytes memory tokenData = abi.encodeWithSignature("initialize(address)", initialOwner);
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImplementation), tokenData);
        address tokenProxyAddress = address(tokenProxy);
        console.log("DKPToken proxy deployed at:", tokenProxyAddress);

        // -- DKP Deployment --
        DKP dkpImplementation = new DKP();
        console.log("DKP implementation deployed at:", address(dkpImplementation));

        bytes memory dkpData = abi.encodeWithSignature("initialize(address,address)", initialOwner, tokenProxyAddress);
        ERC1967Proxy dkpProxy = new ERC1967Proxy(address(dkpImplementation), dkpData);
        address dkpProxyAddress = address(dkpProxy);
        console.log("DKP proxy deployed at:", dkpProxyAddress);

        // Minting tokens
        DKPToken dkpToken = DKPToken(tokenProxyAddress);

        dkpToken.mint(dkpProxyAddress, 10000 ether);
        console.log("Token minted to", dkpProxyAddress, "Amount:", 10000 ether);
        dkpToken.mint(initialOwner, 10000 ether);
        console.log("Token minted to", initialOwner, "Amount:", 10000 ether);

        vm.stopBroadcast();

        console.log("-- Deployment Completed --");
        console.log("DKP Proxy Address:", dkpProxyAddress);
        console.log("Token Proxy Address:", tokenProxyAddress);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DKP} from "../src/DKP.sol";
import {DKPToken} from "../src/DKPToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployDKP is Script {
    function run() external {
        vm.startBroadcast();
        address initialOwner = msg.sender;
        console.log("Initial Owner:", initialOwner);

        address tokenProxyAddress = 0x11D57B15DC8cbd9743370731e2C734bc08117825;

        DKP dkpImplementation = new DKP();
        console.log("DKP implementation deployed at:", address(dkpImplementation));

        bytes memory dkpData = abi.encodeWithSignature("initialize(address,address)", initialOwner, tokenProxyAddress);
        ERC1967Proxy dkpProxy = new ERC1967Proxy(address(dkpImplementation), dkpData);
        address dkpProxyAddress = address(dkpProxy);
        console.log("DKP proxy deployed at:", dkpProxyAddress);

        DKPToken dkpToken = DKPToken(tokenProxyAddress);
        DKP dkpProxyImp = DKP(dkpProxyAddress);
        dkpToken.mint(dkpProxyAddress, 10000 ether);
        console.log("Token minted to", dkpProxyAddress, "Amount:", 10000 ether);

        if (dkpProxyImp.minVoteCountForReview() == 0) {
            dkpProxyImp.setMinVoteCountForReview(100);
            console.log("DKP minVoteCountForReview changed to 100");
        }

        dkpProxyImp.supplyReputation(initialOwner, 1000);
        dkpProxyImp.supplyReputation(0xBf5b4afb5121d54f54De75bC52042b5A2B139C1e, 500);

        vm.stopBroadcast();

        console.log("-- Deployment Completed --");
        console.log("DKP Proxy Address:", dkpProxyAddress);
        console.log("Token Proxy Address:", tokenProxyAddress);
    }
}

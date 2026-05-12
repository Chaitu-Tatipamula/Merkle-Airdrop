// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {Script} from "forge-std/Script.sol";
import {VroomToken} from "../src/VroomToken.sol";

contract DeployMerkleAirdrop is Script {
    VroomToken token;
    MerkleAirdrop airdrop;

    function run() public returns (MerkleAirdrop, VroomToken) {
        vm.startBroadcast();
        bytes32 merckleRoot = 0xc2475430f7e0355b1691d6333a80ddbaf4aa921d6e498c4df6af9a298a7182fe;
        token = new VroomToken();
        airdrop = new MerkleAirdrop(token, merckleRoot);
        token.mint(address(airdrop), 1e23);
        vm.stopBroadcast();

        return (airdrop, token);
    }
}

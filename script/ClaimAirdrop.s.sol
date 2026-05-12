// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "@foundry-devops/DevOpsTools.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";

contract ClaimAirdrop is Script {

    bytes32 public constant MERKLE_ROOT =
        0xc2475430f7e0355b1691d6333a80ddbaf4aa921d6e498c4df6af9a298a7182fe;
    uint256 public constant AMOUNT = 2500e18;
    bytes32 public PROOF0 = 0xc84f370fffe6f29b5ff4ae14c799b15161b7b77d8a664f60d0e0fb251d71d395;
    bytes32 public PROOF1 = 0x6c2ded42dd1d687e15cccc927631c092b43d674e009dcbbe98b5b29ea301ebf8;
    bytes32[] public PROOF = [PROOF0, PROOF1];

    address user = 0xD117738595dfAFe4c2f96bcF63Ed381788E08d39;

    error __ClaimAirdrop__WrongUserPrivateKey();

    function run() external {
        address mostRecentDeployment = DevOpsTools.get_most_recent_deployment("MerkleAirdrop", block.chainid);

        uint256 userPk = vm.envUint("PRIVATE_KEY");
        if (vm.addr(userPk) != user) revert __ClaimAirdrop__WrongUserPrivateKey();

        MerkleAirdrop airdrop = MerkleAirdrop(mostRecentDeployment);
        bytes32 digest = airdrop.getMessageHash(user, AMOUNT);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

        vm.startBroadcast();
        airdrop.claim(user, AMOUNT, PROOF, v, r, s);
        vm.stopBroadcast();
    }
}
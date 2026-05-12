// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Test, console} from "forge-std/Test.sol";
import {VroomToken} from "../src/VroomToken.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {DeployMerkleAirdrop} from "../script/DeployMerkleAirdrop.s.sol";

contract MerkleAirdropTest is Test {
    VroomToken private token;
    MerkleAirdrop public airdrop;

    bytes32 public constant MERKLE_ROOT =
        0xc2475430f7e0355b1691d6333a80ddbaf4aa921d6e498c4df6af9a298a7182fe;
    uint256 public constant AMOUNT = 2500e18;
    bytes32 public PROOF0 = 0xc84f370fffe6f29b5ff4ae14c799b15161b7b77d8a664f60d0e0fb251d71d395;
    bytes32 public PROOF1 = 0x6c2ded42dd1d687e15cccc927631c092b43d674e009dcbbe98b5b29ea301ebf8;
    bytes32[] public PROOF = [PROOF0, PROOF1];

    address user = 0xD117738595dfAFe4c2f96bcF63Ed381788E08d39;
    uint256 key;
    address claimInteractor;

    function setUp() public {
        DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
        (airdrop, token) = deployer.run();
        key = vm.envUint("PRIVATE_KEY");
        claimInteractor = makeAddr("claimer");
    }

    function testUsersCanClaim() public {
        uint256 startingUserBalance = token.balanceOf(user);
        bytes32 digest = airdrop.getMessageHash(user, AMOUNT);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);

        vm.prank(claimInteractor);
        airdrop.claim(user, AMOUNT, PROOF, v, r, s);

        assertEq(token.balanceOf(user), startingUserBalance + AMOUNT);
        assertEq(airdrop.claimStatus(user), true);
    }
}
// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VroomToken} from "../src/VroomToken.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";

contract MerkleAirdropTest is Test {
    /// @dev Well-known Anvil default account #0 — safe to embed for unit tests only.
    address internal constant USER = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    uint256 internal constant DEFAULT_USER_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    VroomToken private token;
    MerkleAirdrop public airdrop;

    uint256 public constant AMOUNT = 2500e18;

    uint256 internal userKey;
    address internal claimInteractor;
    bytes32[] internal proof;

    function setUp() public {
        userKey = vm.envOr("TEST_USER_PRIVATE_KEY", DEFAULT_USER_KEY);
        require(vm.addr(userKey) == USER, "TEST_USER_PRIVATE_KEY must control USER (Anvil #0)");

        // Single-leaf tree: OpenZeppelin MerkleProof.verify([], root, leaf) requires root == leaf.
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(USER, AMOUNT))));
        bytes32 root = leaf;
        proof = new bytes32[](0);

        token = new VroomToken();
        airdrop = new MerkleAirdrop(IERC20(address(token)), root);
        token.mint(address(airdrop), 1e23);

        claimInteractor = makeAddr("claimer");
    }

    function testUsersCanClaim() public {
        uint256 startingUserBalance = token.balanceOf(USER);
        bytes32 digest = airdrop.getMessageHash(USER, AMOUNT);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);

        vm.prank(claimInteractor);
        airdrop.claim(USER, AMOUNT, proof, v, r, s);

        assertEq(token.balanceOf(USER), startingUserBalance + AMOUNT);
        assertEq(airdrop.claimStatus(USER), true);
    }
}

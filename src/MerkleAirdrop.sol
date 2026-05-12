// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract MerkleAirdrop is EIP712 {

    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__InvalidSignature();

    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    bytes32 internal constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account,uint256 amount)");

    using SafeERC20 for IERC20;

    address[] s_claimers;
    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_vroomToken;
    mapping(address => bool) private s_alreadyClaimed;

    event Claim(address indexed account, uint256 indexed amount);

    constructor(IERC20 vroomTokenAddress, bytes32 merckleRoot) EIP712("MerkleAirdrop", "1") {
        i_vroomToken = vroomTokenAddress;
        i_merkleRoot = merckleRoot;

    }

    function claim(
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if(s_alreadyClaimed[account]) {
            revert MerkleAirdrop__AlreadyClaimed();
        }
        if(!_verifySignature(account, getMessageHash(account, amount), v, r, s)) {
            revert MerkleAirdrop__InvalidSignature();
        }
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        bool isValidProof = MerkleProof.verify(merkleProof, i_merkleRoot, leaf);
        if(!isValidProof) {
            revert MerkleAirdrop__InvalidProof();
        }        
        s_alreadyClaimed[account] = true;
        s_claimers.push(account);
        emit Claim(account, amount);
        i_vroomToken.safeTransfer(account, amount);
    }

    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account : account, amount : amount})))
        );
    }

    function _verifySignature(
        address expectedSigner,
        bytes32 digest,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal returns (bool) {
        
        (address recoveredSigner, ,) = ECDSA.tryRecover(digest, v, r, s);

        return expectedSigner == recoveredSigner;
    }

    function getClaimers() external view returns (address[] memory) {
        return s_claimers;
    }

    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns (address) {
        return address(i_vroomToken);
    }

    function claimStatus(address account) external view returns (bool) {
        return s_alreadyClaimed[account];
    }
    
}
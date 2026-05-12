# Merkle Airdrop

ERC-20 airdrop where eligibility is enforced with a **Merkle tree** on-chain and each claim is additionally authorized by an **EIP-712** signature from the recipient. Built with [Foundry](https://book.getfoundry.sh/).

---

## What problem does this solve?

You want to distribute tokens to many addresses without storing the full list in contract storage (expensive) and without letting arbitrary addresses withdraw. You publish a single **Merkle root** on-chain; each user proves they are in the tree with a short **Merkle proof** plus a **signature** that binds the claim to their address and amount.

---

## What is a Merkle tree?

A Merkle tree is a binary tree of hashes:

- **Leaves** are hashes of the data you care about (here: each `(address, amount)` allocation).
- Each **internal node** is the hash of its two children.
- The **root** is one `bytes32` that commits to the entire set of leaves.

**Properties used on-chain:**

1. **Commitment** — Changing any allocation changes the root, so the contract can trust one immutable `merkleRoot`.
2. **Efficient verification** — To prove one leaf belongs to the tree, you only need a logarithmic-size list of sibling hashes (**Merkle proof**), not the full list of users.

**Gas intuition:** Storing `N` addresses in contract storage costs roughly linear gas. Storing one root costs constant gas; each claim pays only for proof length (and a few hashes), which is `O(log N)`.

---

## Leaf format (must match off-chain and on-chain)

This project follows the common **double leaf hash** pattern recommended when using OpenZeppelin-style trees:

```text
leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))))
```

The off-chain generator (`MakeMerkle.s.sol`, Murky) and `MerkleAirdrop` use the same construction so proofs produced from `script/target/input.json` verify against the root you deploy.

---

## How `MerkleAirdrop` works

High-level flow of `claim(account, amount, merkleProof, v, r, s)`:

1. **Already claimed** — Reverts if `account` has claimed before (`s_alreadyClaimed[account]`).
2. **EIP-712 signature** — Builds the typed-data digest for `AirdropClaim { account, amount }` via OpenZeppelin `EIP712` (`name = "MerkleAirdrop"`, `version = "1"`, `verifyingContract = address(this)`). `ecrecover` must equal `account`.  
   - This proves the holder of `account`’s private key agreed to this specific `(account, amount)` for **this** contract and **this** chain.  
   - `msg.sender` is **not** required to be `account`: anyone can relay the transaction (gas payer), which is why the test uses `vm.prank(claimer)`.
3. **Merkle proof** — Recomputes `leaf` from `(account, amount)` and checks `MerkleProof.verify(proof, merkleRoot, leaf)`.
4. **Payout** — Marks `account` as claimed, emits `Claim`, and `safeTransfer`s `amount` of the configured ERC-20 to `account`.

**Important:** The EIP-712 digest includes the **deployed contract address** and **chain id**. A signature produced against another deployment or network will fail with `MerkleAirdrop__InvalidSignature()`.

---

## Repository layout

| Path | Role |
|------|------|
| `src/MerkleAirdrop.sol` | Airdrop logic: Merkle + EIP-712 + ERC-20 transfer |
| `src/VroomToken.sol` | Simple mintable ERC-20 used as the airdrop token |
| `script/GenerateInput.s.sol` | Writes `script/target/input.json` (recipients + amounts) |
| `script/MakeMerkle.s.sol` | Reads input, builds tree with Murky, writes `script/target/output.json` (proofs + root) |
| `script/DeployMerkleAirdrop.s.sol` | Deploys token + airdrop and mints supply to the airdrop contract |
| `script/ClaimAirdrop.s.sol` | Resolves latest `MerkleAirdrop` from broadcast logs, signs digest with `PRIVATE_KEY`, calls `claim` |
| `test/MerkleAirdropTest.t.sol` | Unit test: single-leaf Merkle tree, Anvil #0 signer, relayer `prank` (no env required in CI) |

---

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `cast`, optional `anvil`)
- Submodules: `git submodule update --init --recursive`
- For testnet/mainnet: RPC URL and funded wallet(s)

---

## Setup

```bash
cd airdrop
git submodule update --init --recursive
forge build
forge test
```

---

## End-to-end workflow (new airdrop round)

### 1. Define recipients

Edit `script/GenerateInput.s.sol` (addresses and amount), then:

```bash
forge script script/GenerateInput.s.sol:GenerateInput --sig "run()" -vv
```

This writes `script/target/input.json`.

### 2. Build the Merkle tree and proofs

```bash
forge script script/MakeMerkle.s.sol:MakeMerkle --sig "run()" -vv
```

This writes `script/target/output.json` (per-leaf `inputs`, `proof`, `root`, `leaf`).

### 3. Align on-chain root with off-chain tree

Copy the **`root`** from `output.json` into `script/DeployMerkleAirdrop.s.sol` as `merckleRoot` before deploying (or redeploying) so the contract’s immutable root matches the proofs.

### 4. Deploy (example: Sepolia)

Create a `.env` (never commit it; it is gitignored):

```bash
RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
PRIVATE_KEY=0x...          # deployer / minter
ETHERSCAN_API=...          # optional, for verification
```

```bash
make deploy-sepolia
# or: forge script script/DeployMerkleAirdrop.s.sol:DeployMerkleAirdrop --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast ...
```

### 5. Configure the claim script

`ClaimAirdrop.s.sol` is tied to **one** leaf from `output.json`:

- `user` — recipient address for that leaf  
- `AMOUNT` — must match that leaf’s amount  
- `PROOF0`, `PROOF1`, … — proof siblings from the same JSON entry  
- `MERKLE_ROOT` — informational constant; the live root is whatever was deployed  

`ClaimAirdrop` uses [foundry-devops](https://github.com/ChainAccelOrg/foundry-devops) to read the latest `MerkleAirdrop` address from `broadcast/` for the current `chainid`.

### 6. Claim on-chain

The **same** `PRIVATE_KEY` must control `user` in `ClaimAirdrop.s.sol` (the script signs `getMessageHash(user, AMOUNT)` with that key, then broadcasts `claim`).

```bash
make claim-airdrop
```

**Signing off-line:** You can also use `cast call` on `getMessageHash(address,uint256)` against the **deployed** contract, then `cast wallet sign --no-hash <digest> --private-key ...`, and paste `v,r,s` into a custom script—but the checked-in script signs in-process so the digest always matches the deployment.

---

## Makefile targets

| Target | Purpose |
|--------|---------|
| `make build` | `forge build` |
| `make test` | `forge test` |
| `make deploy-sepolia` | Deploy token + airdrop (uses `.env`) |
| `make claim-airdrop` | Run `ClaimAirdrop` script with `--broadcast` |

---

## Testing

`MerkleAirdropTest` deploys a **one-leaf** Merkle tree: the root equals the leaf hash for `(USER, AMOUNT)`, so the proof array is empty and still passes `MerkleProof.verify` (OpenZeppelin rebuilds `leaf` as the root). The signer is **Anvil account #0** (`0xf39F…` / well-known dev private key) so CI does not need GitHub secrets.

Optional: set `TEST_USER_PRIVATE_KEY` only if you change `USER` in the test and need a matching key.

```bash
forge test
```

The test signs the EIP-712 digest for `USER` and calls `claim` from a different address (`makeAddr("claimer")`) to mirror a relayer paying gas.

---

## CI

`.github/workflows/test.yml` runs `forge fmt --check`, `forge build --sizes`, and `forge test`. No repository secrets are required.

---

## Security and hygiene notes

- **Private keys** belong in `.env` or CI secrets, never in source or committed broadcast files.
- **EIP-712 signatures** for `claim` are not generic wallet keys; they only authorize that typed message for that contract and chain. After a successful claim they are already public in transaction calldata. This repo **gitignores** `broadcast/ClaimAirdrop.s.sol/` to avoid committing redundant signature-bearing artifacts; deploy broadcasts remain for address discovery.
- **Merkle root** is immutable after deploy. To change allocations, deploy a new `MerkleAirdrop` (and fund it) with a new root.

---

## Further reading

- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin MerkleProof](https://docs.openzeppelin.com/contracts/api/utils#MerkleProof)
- [OpenZeppelin EIP-712](https://docs.openzeppelin.com/contracts/api/utils#EIP712)
- [EIP-712: Typed structured data hashing and signing](https://eips.ethereum.org/EIPS/eip-712)

---

## License

See SPDX identifiers in individual source files.

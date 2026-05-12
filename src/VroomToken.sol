// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VroomToken is ERC20, Ownable(msg.sender) {
    constructor() ERC20("VroomToken", "VRO") {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
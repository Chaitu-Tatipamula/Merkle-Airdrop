// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Script} from "forge-std/Script.sol";

contract GenerateInput is Script {
    string constant FILE_PATH = "script/target/input.json";

    function run() external {
        string[] memory types = new string[](2);
        types[0] = "address";
        types[1] = "uint";

        uint256 amount = 2500 * 1e18;

        address[] memory addresses = new address[](4);
        addresses[0] = 0xD117738595dfAFe4c2f96bcF63Ed381788E08d39;
        addresses[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        addresses[2] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        addresses[3] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

        string memory json = createJSON(types, amount, addresses);
        vm.writeFile(FILE_PATH, json);
    }

    function createJSON(string[] memory types, uint256 amount, address[] memory addresses)
        internal
        pure
        returns (string memory)
    {
        string memory json = "{";

        json = string.concat(json, "\"types\" : [ ");
        for (uint256 i = 0; i < types.length; i++) {
            json = string.concat(json, "\"", types[i], "\"");
            if (i < types.length - 1) {
                json = string.concat(json, ",");
            }
        }
        json = string.concat(json, "], ");

        json = string.concat(json, "\"count\": ", vm.toString(uint256(addresses.length)), ",");

        json = string.concat(json, "\"values\" : {");
        for (uint256 i = 0; i < addresses.length; i++) {
            json = string.concat(
                json,
                "\"",
                vm.toString(i),
                "\": {",
                "\"0\": \"",
                vm.toString(addresses[i]),
                "\",",
                "\"1\": \"",
                vm.toString(amount),
                "\"}"
            );
            if (i < addresses.length - 1) {
                json = string.concat(json, ",");
            }
        }
        json = string.concat(json, "}}");
        return json;
    }
}

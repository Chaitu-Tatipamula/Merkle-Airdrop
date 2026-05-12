// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Script} from "forge-std/Script.sol";
import {Merkle} from "@murky/src/Merkle.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ScriptHelper} from "murky/script/common/ScriptHelper.sol";



contract MakeMerkle is Script, ScriptHelper {
    using stdJson for string;

    string private inputPath = "/script/target/input.json";
    string private outputPath = "/script/target/output.json";

    Merkle private merky = new Merkle();

    string private elements = vm.readFile(string.concat(vm.projectRoot(), inputPath)) ;
    string[] private types = elements.readStringArray(".types");
    uint256 private count = elements.readUint(".count");
    
    bytes32[] private leafs = new bytes32[](count); 
    string[] private inputs = new string[](count); 
    string[] private outputs = new string[](count); 

    string private output;
     
    function run() external {

        for(uint i = 0; i < count; i++){
            string[] memory input = new string[](types.length);
            bytes32[] memory data = new bytes32[](types.length);

            for(uint j = 0; j < types.length; j++){
                if(compareStrings(types[j], "address")){
                    address value = elements.readAddress(getValuesByIndex(i, j));
                    data[j] = bytes32(uint256(uint160(value)));
                    input[j] = vm.toString(value);
                } else if (compareStrings(types[j], "uint")) {
                    uint256 value = vm.parseUint(elements.readString(getValuesByIndex(i, j)));
                    data[j] = bytes32(value);
                    input[j] = vm.toString(value); 
                }
            }

            leafs[i] = keccak256(bytes.concat(keccak256(ltrim64(abi.encode(data)))));

            inputs[i] = stringArrayToString(input);
        }

        for(uint i = 0; i < count; i++){
            string memory proof = bytes32ArrayToString(merky.getProof(leafs, i));
            string memory root = vm.toString(merky.getRoot(leafs));
            string memory leaf = vm.toString(leafs[i]);
            string memory input = inputs[i];

            outputs[i] = generateJsonEntries(input, proof, root, leaf);
        }

        output = stringArrayToArrayString(outputs);
        vm.writeFile(string.concat(vm.projectRoot(), outputPath), output);
    }

    function getValuesByIndex(uint256 i, uint256 j) internal pure returns (string memory) {
        return string.concat(".values.", vm.toString(i), ".", vm.toString(j));
    }

    function generateJsonEntries(string memory inputs, string memory proof, string memory root, string memory leaf) internal pure returns (string memory result) {
        result = string.concat(
            "{",
            "\"inputs\":",
            inputs,
            ",",
            "\"proof\":",
            proof,
            ",",
            "\"root\":\"",
            root,
            "\",",
            "\"leaf\":\"",
            leaf,
            "\"",
            "}"

        );
    }

}
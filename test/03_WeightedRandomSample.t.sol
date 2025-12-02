// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "lib/forge-std/src/Test.sol";
import {console2 as console} from "lib/forge-std/src/console2.sol";

// NOTE: Adjust this import path to where ExposedSortitionSumTreeFactory is located in your repo.
// The test assumes the contract provides: _createTree(bytes32, uint256), _set(bytes32, uint256, bytes32),
// _draw(bytes32, uint256) returns (bytes32), and _stakeOf(bytes32, bytes32) returns (uint256).
import {ExposedSortitionSumTreeFactory} from "src/challenges/03_WeightedRandomSample.sol";

contract WeightedRandomSampleTest is Test {
	ExposedSortitionSumTreeFactory sortitionSumTreeFactory;

	struct Candidate { bytes32 ID; uint256 value; }

	function setUp() public {
		sortitionSumTreeFactory = new ExposedSortitionSumTreeFactory();
	}

	function test_SortitionSumTreeFactory_Workflow() public {
		// Create tree and populate with 4 candidates
		bytes32 treeKey = bytes32(abi.encodePacked(uint256(1)));
		uint256 K = 2;


		Candidate memory bob = Candidate({
			ID: 0x0000000000000000000000000000000000000000000000000000000000000002,
			value: 15
		});
		Candidate memory dave = Candidate({
			ID: 0x0000000000000000000000000000000000000000000000000000000000000004,
			value: 5
		});
		Candidate memory alice = Candidate({
			ID: 0x0000000000000000000000000000000000000000000000000000000000000001,
			value: 10
		});
		Candidate memory carl = Candidate({
			ID: 0x0000000000000000000000000000000000000000000000000000000000000003,
			value: 20
		});

		sortitionSumTreeFactory._createTree(treeKey, K);

		sortitionSumTreeFactory._set(treeKey, bob.value, bob.ID);
	_logTree(treeKey, "after set bob");
		sortitionSumTreeFactory._set(treeKey, dave.value, dave.ID);
	_logTree(treeKey, "after set dave");
		sortitionSumTreeFactory._set(treeKey, alice.value, alice.ID);
	_logTree(treeKey, "after set alice");
		sortitionSumTreeFactory._set(treeKey, carl.value, carl.ID);
	_logTree(treeKey, "after set carl");

		// Test drawing Bob with 13 and Carl with 27
		assertEq(sortitionSumTreeFactory._draw(treeKey, 13), bob.ID);
		assertEq(sortitionSumTreeFactory._draw(treeKey, 27), carl.ID);

		// Set Alice to 14 to draw her with 13 and then set her back to 10 to draw Bob again
		sortitionSumTreeFactory._set(treeKey, 14, alice.ID);
	_logTree(treeKey, "after update alice to 14");
		assertEq(sortitionSumTreeFactory._draw(treeKey, 13), alice.ID);
		sortitionSumTreeFactory._set(treeKey, 10, alice.ID);
	_logTree(treeKey, "after update alice back to 10");
		assertEq(sortitionSumTreeFactory._draw(treeKey, 13), bob.ID);

		// Remove Carl to draw Dave with 27 and add him back in to draw him again
		sortitionSumTreeFactory._set(treeKey, 0, carl.ID);
	_logTree(treeKey, "after remove carl");
		assertEq(sortitionSumTreeFactory._draw(treeKey, 27), dave.ID);

		sortitionSumTreeFactory._set(treeKey, carl.value, carl.ID);
	_logTree(treeKey, "after add back carl");
		assertEq(sortitionSumTreeFactory._draw(treeKey, 27), carl.ID);

		// Test stake view
		assertEq(sortitionSumTreeFactory._stakeOf(treeKey, bob.ID), bob.value);
		assertEq(sortitionSumTreeFactory._stakeOf(treeKey, dave.ID), dave.value);
		assertEq(sortitionSumTreeFactory._stakeOf(treeKey, alice.ID), alice.value);
		assertEq(sortitionSumTreeFactory._stakeOf(treeKey, carl.ID), carl.value);
	}

	function _logTree(bytes32 key, string memory label) internal view {
		(uint256[] memory nodes, bytes32[] memory ids) = sortitionSumTreeFactory._debugTree(key);
		console.log(label);
		console.log("nodes.length:");
		console.log(nodes.length);
		for (uint256 i; i < nodes.length; ++i) {
			console.log("index:");
			console.log(i);
			console.log("value:");
			console.log(nodes[i]);
			console.log("id:");
			console.logBytes32(ids[i]);
		}
	}
}
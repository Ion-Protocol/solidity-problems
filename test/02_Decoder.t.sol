// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "lib/forge-std/src/Test.sol";
import {UniswapDecoder} from "src/challenges/02_Decoder.sol";

contract DecoderTest is Test {
    UniswapDecoder decoder;

    function setUp() public {
        decoder = new UniswapDecoder();
    }

    function buildPath(address[] memory tokens, uint24[] memory fees) internal pure returns (bytes memory path) {
        require(tokens.length >= 2, "need >=2 tokens");
        require(fees.length == tokens.length - 1, "fees len");

        path = abi.encodePacked(tokens[0]);

        for (uint256 i; i < fees.length; ++i) {
            bytes memory feeBytes = abi.encodePacked(fees[i]);
            bytes memory fee3 = new bytes(3);
            for (uint256 j; j < 3; ++j) {
                fee3[j] = feeBytes[feeBytes.length - 3 + j];
            }

            path = abi.encodePacked(path, fee3, tokens[i + 1]);
        }
    }

    function expectedOutput(address[] memory tokens, address recipient) internal pure returns (bytes memory out) {
        bytes memory buf;
        for (uint256 i = 0; i < tokens.length; ++i) {
            buf = abi.encodePacked(buf, tokens[i]);
        }
        out = abi.encodePacked(buf, recipient);
    }

    function test_DecodeOneHop() public {
        address tokenA = address(uint160(uint256(keccak256("tokenA"))));
        address tokenB = address(uint160(uint256(keccak256("tokenB"))));
        address recipient = address(uint160(uint256(keccak256("recipient"))));
        uint24 fee = 3000; // 0.3%

        address[] memory tokens = new address[](2);
        tokens[0] = tokenA;
        tokens[1] = tokenB;
        uint24[] memory fees = new uint24[](1);
        fees[0] = fee;

        bytes memory path = buildPath(tokens, fees);

        UniswapDecoder.ExactInputParams memory params = UniswapDecoder.ExactInputParams({
            path: path,
            recipient: recipient,
            deadline: 0,
            amountIn: 0,
            amountOutMinimum: 0
        });

        // staticcall the decoder
        (bool ok, bytes memory ret) = address(decoder).staticcall(
            abi.encodeWithSelector(UniswapDecoder.exactInput.selector, params)
        );
        assertTrue(ok, "staticcall failed");

        bytes memory addressesFound = abi.decode(ret, (bytes));
        bytes memory expected = expectedOutput(tokens, recipient);
        assertEq(addressesFound, expected, "one hop decode mismatch");
    }

    function test_DecodeTwoHops() public {
        address tokenA = address(uint160(uint256(keccak256("tokenA"))));
        address tokenB = address(uint160(uint256(keccak256("tokenB"))));
        address tokenC = address(uint160(uint256(keccak256("tokenC"))));
        address recipient = address(uint160(uint256(keccak256("recipient"))));
        uint24 feeAB = 500;  // 0.05%
        uint24 feeBC = 10000; // 1%

        address[] memory tokens = new address[](3);
        tokens[0] = tokenA;
        tokens[1] = tokenB;
        tokens[2] = tokenC;

        uint24[] memory fees = new uint24[](2);
        fees[0] = feeAB;
        fees[1] = feeBC;

        bytes memory path = buildPath(tokens, fees);

        UniswapDecoder.ExactInputParams memory params = UniswapDecoder.ExactInputParams({
            path: path,
            recipient: recipient,
            deadline: 0,
            amountIn: 0,
            amountOutMinimum: 0
        });

        (bool ok, bytes memory ret) = address(decoder).staticcall(
            abi.encodeWithSelector(UniswapDecoder.exactInput.selector, params)
        );
        assertTrue(ok, "staticcall failed");

        bytes memory addressesFound = abi.decode(ret, (bytes));
        bytes memory expected = expectedOutput(tokens, recipient);
        assertEq(addressesFound, expected, "two hops decode mismatch");
    }

    function test_DecodeArbitraryHops() public {
        uint8 hops = 10;
        address recipient = address(uint160(uint256(keccak256("recipient"))));

        address[] memory tokens = new address[](hops + 1);
        uint24[] memory fees = new uint24[](hops);

        for (uint256 i; i < tokens.length; ++i) {
            tokens[i] = address(uint160(uint256(keccak256(abi.encodePacked("tok", i)))));
        }
        for (uint256 i; i < hops; ++i) {
            fees[i] = uint24(500 + i);
        }

        bytes memory path = buildPath(tokens, fees);

        UniswapDecoder.ExactInputParams memory params = UniswapDecoder.ExactInputParams({
            path: path,
            recipient: recipient,
            deadline: 0,
            amountIn: 0,
            amountOutMinimum: 0
        });

        (bool ok, bytes memory ret) = address(decoder).staticcall(
            abi.encodeWithSelector(UniswapDecoder.exactInput.selector, params)
        );
        assertTrue(ok, "staticcall failed");

        bytes memory addressesFound = abi.decode(ret, (bytes));
        bytes memory expected = expectedOutput(tokens, recipient);
        assertEq(addressesFound, expected, "arbitrary hops decode mismatch");
    }

    function test_RevertOnBadPathFormat() public {
        // Build an invalid path length that violates (pathLength % 23 != 20)
        // For example, 21 bytes (neither initial 20 nor 20 + n*23)
        bytes memory badPath = new bytes(21);
        address recipient = address(uint160(uint256(keccak256("recipient"))));

        UniswapDecoder.ExactInputParams memory params = UniswapDecoder.ExactInputParams({
            path: badPath,
            recipient: recipient,
            deadline: 0,
            amountIn: 0,
            amountOutMinimum: 0
        });

        // Expect revert due to bad path format
        vm.expectRevert();
        decoder.exactInput(params);
    }
}

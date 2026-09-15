// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Placeholder} from "../src/Placeholder.sol";

/**
 * @title PlaceholderTest
 * @notice Smoke tests Fase 0: compilacion, remappings OZ y fuzz basico.
 */
contract PlaceholderTest is Test {
    Placeholder internal placeholder;

    function setUp() public {
        placeholder = new Placeholder();
    }

    function test_PingReturnsInput() public view {
        assertEq(placeholder.ping(42), 42);
    }

    function test_RemappingOpenZeppelinIERC20() public pure {
        // Valida que @openzeppelin/contracts remapea correctamente (selector Transfer).
        bytes4 transferSelector = IERC20.transfer.selector;
        assertTrue(transferSelector != bytes4(0));
    }

    function testFuzz_Ping(uint256 value) public view {
        assertEq(placeholder.ping(value), value);
    }
}

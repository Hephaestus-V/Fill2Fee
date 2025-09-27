// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Counter.sol";

contract CounterTest is Test {
    Counter private counter;

    function setUp() public {
        counter = new Counter();
    }

    function test_InitialNumberIsZero() public {
        assertEq(counter.number(), 0);
    }

    function test_Increment() public {
        counter.setNumber(41);
        counter.increment();
        assertEq(counter.number(), 42);
    }
}



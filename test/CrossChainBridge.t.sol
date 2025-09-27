// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/CrossChainBridge.sol";
import "../src/Fill2FeeToken.sol";
import "../src/SecurityManager.sol";

/**
 * @title CrossChainBridgeTest
 * @dev Comprehensive tests for CrossChainBridge contract
 * @author Fill2Fee Team
 */
contract CrossChainBridgeTest is Test {
    CrossChainBridge public bridge;
    Fill2FeeToken public token;
    SecurityManager public securityManager;
    
    address public owner;
    address public user1;
    address public user2;
    address public attacker;
    
    uint256 public constant INITIAL_BALANCE = 100 ether;
    uint256 public constant DEPOSIT_AMOUNT = 1 ether;
    uint256 public constant TARGET_CHAIN_ID = 137; // Polygon
    
    event DepositInitiated(
        address indexed user,
        uint256 indexed chainId,
        uint256 amount,
        bytes32 indexed depositId
    );
    
    event WithdrawalCompleted(
        address indexed user,
        uint256 indexed chainId,
        uint256 amount,
        bytes32 indexed depositId
    );

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        attacker = makeAddr("attacker");
        
        // Deploy contracts
        bridge = new CrossChainBridge();
        token = new Fill2FeeToken();
        securityManager = new SecurityManager();
        
        // Configure system
        token.setBridgeContract(address(bridge));
        bridge.addSupportedChain(TARGET_CHAIN_ID);
        
        // Fund users
        vm.deal(user1, INITIAL_BALANCE);
        vm.deal(user2, INITIAL_BALANCE);
        vm.deal(attacker, INITIAL_BALANCE);
        
        // Fund bridge
        vm.deal(address(bridge), 10 ether);
    }

    function testInitialState() public {
        assertEq(bridge.owner(), owner);
        assertEq(bridge.currentChainId(), block.chainid);
        assertTrue(bridge.supportedChains(block.chainid));
        assertTrue(bridge.supportedChains(TARGET_CHAIN_ID));
        assertEq(bridge.totalDeposits(), 0);
        assertEq(bridge.totalWithdrawals(), 0);
    }

    function testInitiateDeposit() public {
        vm.startPrank(user1);
        
        uint256 initialBalance = address(bridge).balance;
        
        vm.expectEmit(true, true, true, true);
        emit DepositInitiated(user1, TARGET_CHAIN_ID, DEPOSIT_AMOUNT, bytes32(0));
        
        bytes32 depositId = bridge.initiateDeposit{value: DEPOSIT_AMOUNT}(TARGET_CHAIN_ID);
        
        assertTrue(depositId != bytes32(0));
        assertTrue(bridge.isDepositProcessed(depositId));
        assertEq(address(bridge).balance, initialBalance + DEPOSIT_AMOUNT);
        assertEq(bridge.totalDeposits(), DEPOSIT_AMOUNT);
        
        vm.stopPrank();
    }

    function testInitiateDepositInvalidChain() public {
        vm.startPrank(user1);
        
        vm.expectRevert("Cannot deposit to same chain");
        bridge.initiateDeposit{value: DEPOSIT_AMOUNT}(block.chainid);
        
        vm.expectRevert("Chain not supported");
        bridge.initiateDeposit{value: DEPOSIT_AMOUNT}(999);
        
        vm.stopPrank();
    }

    function testInitiateDepositInvalidAmount() public {
        vm.startPrank(user1);
        
        vm.expectRevert("Deposit too small");
        bridge.initiateDeposit{value: 0.0001 ether}(TARGET_CHAIN_ID);
        
        vm.expectRevert("Deposit too large");
        bridge.initiateDeposit{value: 200 ether}(TARGET_CHAIN_ID);
        
        vm.stopPrank();
    }

    function testCompleteWithdrawal() public {
        // First, create a deposit
        vm.startPrank(user1);
        bytes32 depositId = bridge.initiateDeposit{value: DEPOSIT_AMOUNT}(TARGET_CHAIN_ID);
        vm.stopPrank();
        
        // Now complete withdrawal as owner
        uint256 initialUserBalance = user2.balance;
        
        vm.expectEmit(true, true, true, true);
        emit WithdrawalCompleted(user2, block.chainid, DEPOSIT_AMOUNT, depositId);
        
        bridge.completeWithdrawal(user2, DEPOSIT_AMOUNT, depositId, block.chainid);
        
        assertEq(user2.balance, initialUserBalance + DEPOSIT_AMOUNT);
        assertEq(bridge.totalWithdrawals(), DEPOSIT_AMOUNT);
    }

    function testCompleteWithdrawalInvalid() public {
        bytes32 fakeDepositId = keccak256("fake");
        
        vm.expectRevert("Withdrawal already processed");
        bridge.completeWithdrawal(user1, DEPOSIT_AMOUNT, fakeDepositId, block.chainid);
    }

    function testCompleteWithdrawalInsufficientBalance() public {
        vm.startPrank(user1);
        bytes32 depositId = bridge.initiateDeposit{value: DEPOSIT_AMOUNT}(TARGET_CHAIN_ID);
        vm.stopPrank();
        
        // Try to withdraw more than bridge has
        vm.expectRevert("Insufficient bridge balance");
        bridge.completeWithdrawal(user1, 100 ether, depositId, block.chainid);
    }

    function testAddRemoveSupportedChain() public {
        uint256 newChainId = 56; // BSC
        
        bridge.addSupportedChain(newChainId);
        assertTrue(bridge.supportedChains(newChainId));
        
        bridge.removeSupportedChain(newChainId);
        assertFalse(bridge.supportedChains(newChainId));
    }

    function testAddRemoveSupportedChainInvalid() public {
        vm.expectRevert("Cannot add current chain");
        bridge.addSupportedChain(block.chainid);
        
        vm.expectRevert("Cannot remove current chain");
        bridge.removeSupportedChain(block.chainid);
    }

    function testGetBridgeStats() public {
        vm.startPrank(user1);
        bridge.initiateDeposit{value: DEPOSIT_AMOUNT}(TARGET_CHAIN_ID);
        vm.stopPrank();
        
        (uint256 totalDeposits, uint256 totalWithdrawals, uint256 bridgeBalance) = bridge.getBridgeStats();
        
        assertEq(totalDeposits, DEPOSIT_AMOUNT);
        assertEq(totalWithdrawals, 0);
        assertEq(bridgeBalance, address(bridge).balance);
    }

    function testEmergencyWithdraw() public {
        uint256 initialOwnerBalance = owner.balance;
        uint256 withdrawAmount = 5 ether;
        
        bridge.emergencyWithdraw(withdrawAmount);
        
        assertEq(owner.balance, initialOwnerBalance + withdrawAmount);
    }

    function testEmergencyWithdrawInvalid() public {
        vm.expectRevert("Insufficient balance");
        bridge.emergencyWithdraw(1000 ether);
        
        vm.expectRevert("Amount must be positive");
        bridge.emergencyWithdraw(0);
    }

    function testReceiveFunction() public {
        uint256 initialBalance = address(bridge).balance;
        uint256 sendAmount = 1 ether;
        
        (bool success, ) = address(bridge).call{value: sendAmount}("");
        assertTrue(success);
        assertEq(address(bridge).balance, initialBalance + sendAmount);
    }

    function testOnlyOwnerModifier() public {
        vm.startPrank(attacker);
        
        vm.expectRevert("Only owner can call this function");
        bridge.addSupportedChain(56);
        
        vm.expectRevert("Only owner can call this function");
        bridge.emergencyWithdraw(1 ether);
        
        vm.stopPrank();
    }

    function testMultipleDeposits() public {
        vm.startPrank(user1);
        
        bytes32 depositId1 = bridge.initiateDeposit{value: DEPOSIT_AMOUNT}(TARGET_CHAIN_ID);
        bytes32 depositId2 = bridge.initiateDeposit{value: DEPOSIT_AMOUNT}(TARGET_CHAIN_ID);
        
        assertTrue(depositId1 != depositId2);
        assertTrue(bridge.isDepositProcessed(depositId1));
        assertTrue(bridge.isDepositProcessed(depositId2));
        assertEq(bridge.totalDeposits(), DEPOSIT_AMOUNT * 2);
        
        vm.stopPrank();
    }

    function testDepositIdUniqueness() public {
        vm.startPrank(user1);
        
        // Create multiple deposits with same parameters
        bytes32 depositId1 = bridge.initiateDeposit{value: DEPOSIT_AMOUNT}(TARGET_CHAIN_ID);
        
        // Advance time to ensure different timestamp
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        
        bytes32 depositId2 = bridge.initiateDeposit{value: DEPOSIT_AMOUNT}(TARGET_CHAIN_ID);
        
        assertTrue(depositId1 != depositId2);
        
        vm.stopPrank();
    }

    function testFuzzDeposit(uint256 amount, uint256 chainId) public {
        vm.assume(amount >= 0.001 ether && amount <= 100 ether);
        vm.assume(chainId != block.chainid);
        vm.assume(chainId != 0);
        
        bridge.addSupportedChain(chainId);
        
        vm.deal(user1, amount);
        vm.startPrank(user1);
        
        bytes32 depositId = bridge.initiateDeposit{value: amount}(chainId);
        assertTrue(depositId != bytes32(0));
        assertTrue(bridge.isDepositProcessed(depositId));
        
        vm.stopPrank();
    }
}

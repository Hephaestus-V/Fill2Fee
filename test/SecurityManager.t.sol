// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/SecurityManager.sol";

/**
 * @title SecurityManagerTest
 * @dev Comprehensive tests for SecurityManager contract
 * @author Fill2Fee Team
 */
contract SecurityManagerTest is Test {
    SecurityManager public securityManager;
    
    address public owner;
    address public securityAdmin;
    address public user1;
    address public user2;
    address public attacker;
    
    uint256 public constant TEST_AMOUNT = 1 ether;
    uint256 public constant TARGET_CHAIN_ID = 137;

    event SecurityAlert(
        string indexed alertType,
        address indexed target,
        uint256 severity,
        string message
    );
    
    event RateLimitExceeded(
        address indexed user,
        uint256 amount,
        uint256 limit
    );

    function setUp() public {
        owner = address(this);
        securityAdmin = makeAddr("securityAdmin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        attacker = makeAddr("attacker");
        
        securityManager = new SecurityManager();
        
        // Set security admin
        vm.prank(owner);
        securityManager.addValidator(securityAdmin);
    }

    function testInitialState() public {
        assertEq(securityManager.owner(), owner);
        assertEq(securityManager.securityAdmin(), securityAdmin);
        assertFalse(securityManager.blacklistedAddresses(user1));
        assertFalse(securityManager.whitelistedAddresses(user1));
        assertEq(securityManager.totalAlerts(), 0);
    }

    function testValidateTransferValid() public {
        (bool isValid, string memory reason) = securityManager.validateTransfer(
            user1,
            TEST_AMOUNT,
            TARGET_CHAIN_ID
        );
        
        assertTrue(isValid);
        assertEq(reason, "Transfer validated");
    }

    function testValidateTransferBlacklisted() public {
        vm.prank(securityAdmin);
        securityManager.addToBlacklist(user1);
        
        (bool isValid, string memory reason) = securityManager.validateTransfer(
            user1,
            TEST_AMOUNT,
            TARGET_CHAIN_ID
        );
        
        assertFalse(isValid);
        assertEq(reason, "User is blacklisted");
    }

    function testValidateTransferEmergencyPause() public {
        vm.prank(securityAdmin);
        securityManager.enableEmergencyPause();
        
        (bool isValid, string memory reason) = securityManager.validateTransfer(
            user1,
            TEST_AMOUNT,
            TARGET_CHAIN_ID
        );
        
        assertFalse(isValid);
        assertEq(reason, "System is in emergency pause");
    }

    function testValidateTransferMaintenanceMode() public {
        vm.prank(securityAdmin);
        securityManager.enableMaintenanceMode();
        
        (bool isValid, string memory reason) = securityManager.validateTransfer(
            user1,
            TEST_AMOUNT,
            TARGET_CHAIN_ID
        );
        
        assertFalse(isValid);
        assertEq(reason, "System is in maintenance mode");
    }

    function testValidateTransferAmountTooSmall() public {
        (bool isValid, string memory reason) = securityManager.validateTransfer(
            user1,
            0.0001 ether,
            TARGET_CHAIN_ID
        );
        
        assertFalse(isValid);
        assertEq(reason, "Amount below minimum threshold");
    }

    function testValidateTransferAmountTooLarge() public {
        (bool isValid, string memory reason) = securityManager.validateTransfer(
            user1,
            200 ether,
            TARGET_CHAIN_ID
        );
        
        assertFalse(isValid);
        assertEq(reason, "Amount exceeds maximum single transfer");
    }

    function testRecordTransfer() public {
        bytes32 txHash = keccak256("test-tx");
        
        vm.prank(securityAdmin);
        securityManager.recordTransfer(user1, TEST_AMOUNT, TARGET_CHAIN_ID, txHash);
        
        (bool isBlacklisted, bool isWhitelisted) = securityManager.getUserSecurityStatus(user1);
        assertFalse(isBlacklisted);
        assertFalse(isWhitelisted);
    }

    function testRecordTransferDuplicate() public {
        bytes32 txHash = keccak256("test-tx");
        
        vm.startPrank(securityAdmin);
        securityManager.recordTransfer(user1, TEST_AMOUNT, TARGET_CHAIN_ID, txHash);
        
        vm.expectRevert("Transaction already processed");
        securityManager.recordTransfer(user1, TEST_AMOUNT, TARGET_CHAIN_ID, txHash);
        vm.stopPrank();
    }

    function testAddRemoveBlacklist() public {
        vm.prank(securityAdmin);
        securityManager.addToBlacklist(user1);
        
        assertTrue(securityManager.blacklistedAddresses(user1));
        
        vm.prank(securityAdmin);
        securityManager.removeFromBlacklist(user1);
        
        assertFalse(securityManager.blacklistedAddresses(user1));
    }

    function testAddRemoveWhitelist() public {
        vm.prank(securityAdmin);
        securityManager.addToWhitelist(user1);
        
        assertTrue(securityManager.whitelistedAddresses(user1));
        
        vm.prank(securityAdmin);
        securityManager.removeFromWhitelist(user1);
        
        assertFalse(securityManager.whitelistedAddresses(user1));
    }

    function testSetSecurityConfig() public {
        vm.prank(securityAdmin);
        securityManager.setSecurityConfig(
            200 ether,    // max daily volume
            20 ether,     // max single transfer
            0.01 ether,   // min transfer amount
            2 hours       // cooldown period
        );
        
        // Test with new limits
        (bool isValid, ) = securityManager.validateTransfer(user1, 15 ether, TARGET_CHAIN_ID);
        assertTrue(isValid);
        
        (bool isValid2, ) = securityManager.validateTransfer(user1, 25 ether, TARGET_CHAIN_ID);
        assertFalse(isValid2);
    }

    function testEmergencyPause() public {
        vm.prank(securityAdmin);
        securityManager.enableEmergencyPause();
        
        assertTrue(securityManager.securityConfig().emergencyPause);
        
        vm.prank(owner);
        securityManager.disableEmergencyPause();
        
        assertFalse(securityManager.securityConfig().emergencyPause);
    }

    function testMaintenanceMode() public {
        vm.prank(securityAdmin);
        securityManager.enableMaintenanceMode();
        
        assertTrue(securityManager.securityConfig().maintenanceMode);
        
        vm.prank(securityAdmin);
        securityManager.disableMaintenanceMode();
        
        assertFalse(securityManager.securityConfig().maintenanceMode);
    }

    function testResetUserLimits() public {
        // Record some transfers
        vm.startPrank(securityAdmin);
        securityManager.recordTransfer(user1, TEST_AMOUNT, TARGET_CHAIN_ID, keccak256("tx1"));
        securityManager.recordTransfer(user1, TEST_AMOUNT, TARGET_CHAIN_ID, keccak256("tx2"));
        vm.stopPrank();
        
        // Reset limits
        vm.prank(securityAdmin);
        securityManager.resetUserLimits(user1);
        
        // User should be able to transfer again
        (bool isValid, ) = securityManager.validateTransfer(user1, TEST_AMOUNT, TARGET_CHAIN_ID);
        assertTrue(isValid);
    }

    function testOnlyOwnerModifier() public {
        vm.startPrank(attacker);
        
        vm.expectRevert("Only owner can call this function");
        securityManager.disableEmergencyPause();
        
        vm.stopPrank();
    }

    function testOnlySecurityAdminModifier() public {
        vm.startPrank(user1);
        
        vm.expectRevert("Only security admin can call this function");
        securityManager.addToBlacklist(user2);
        
        vm.expectRevert("Only security admin can call this function");
        securityManager.enableEmergencyPause();
        
        vm.stopPrank();
    }

    function testSuspiciousActivityDetection() public {
        vm.startPrank(securityAdmin);
        
        // Record multiple rapid transfers
        for (uint256 i = 0; i < 15; i++) {
            securityManager.recordTransfer(
                user1, 
                TEST_AMOUNT, 
                TARGET_CHAIN_ID, 
                keccak256(abi.encodePacked("tx", i))
            );
        }
        
        vm.stopPrank();
        
        // Should have triggered alerts
        assertTrue(securityManager.totalAlerts() > 0);
    }

    function testGetUserSecurityStatus() public {
        vm.prank(securityAdmin);
        securityManager.addToWhitelist(user1);
        
        vm.prank(securityAdmin);
        securityManager.addToBlacklist(user2);
        
        (bool isBlacklisted1, bool isWhitelisted1) = securityManager.getUserSecurityStatus(user1);
        (bool isBlacklisted2, bool isWhitelisted2) = securityManager.getUserSecurityStatus(user2);
        
        assertFalse(isBlacklisted1);
        assertTrue(isWhitelisted1);
        assertTrue(isBlacklisted2);
        assertFalse(isWhitelisted2);
    }

    function testGetSecurityStats() public {
        vm.prank(securityAdmin);
        securityManager.enableEmergencyPause();
        
        (uint256 totalAlerts, uint256 emergencyPauseTime, ) = securityManager.getSecurityStats();
        
        assertTrue(totalAlerts > 0);
        assertTrue(emergencyPauseTime > 0);
    }

    function testFuzzSecurityConfig(
        uint256 maxDailyVolume,
        uint256 maxSingleTransfer,
        uint256 minTransferAmount,
        uint256 cooldownPeriod
    ) public {
        vm.assume(maxDailyVolume > 0 && maxDailyVolume <= 10000 ether);
        vm.assume(maxSingleTransfer > 0 && maxSingleTransfer <= 1000 ether);
        vm.assume(minTransferAmount > 0 && minTransferAmount <= 1 ether);
        vm.assume(cooldownPeriod > 0 && cooldownPeriod <= 24 hours);
        
        vm.prank(securityAdmin);
        securityManager.setSecurityConfig(
            maxDailyVolume,
            maxSingleTransfer,
            minTransferAmount,
            cooldownPeriod
        );
        
        // Test with valid amount
        (bool isValid, ) = securityManager.validateTransfer(
            user1, 
            minTransferAmount, 
            TARGET_CHAIN_ID
        );
        assertTrue(isValid);
    }

    function testBlacklistOwner() public {
        vm.prank(securityAdmin);
        vm.expectRevert("Cannot blacklist owner");
        securityManager.addToBlacklist(owner);
    }

    function testRemoveNonBlacklisted() public {
        vm.prank(securityAdmin);
        vm.expectRevert("Address not blacklisted");
        securityManager.removeFromBlacklist(user1);
    }

    function testRemoveNonWhitelisted() public {
        vm.prank(securityAdmin);
        vm.expectRevert("Address not whitelisted");
        securityManager.removeFromWhitelist(user1);
    }
}

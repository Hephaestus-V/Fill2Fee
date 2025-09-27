// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/CrossChainBridge.sol";
import "../src/Fill2FeeToken.sol";
import "../src/CrossChainMessenger.sol";
import "../src/SecurityManager.sol";

/**
 * @title DeployTestnet
 * @dev Testnet deployment script with additional test configurations
 * @author Fill2Fee Team
 */
contract DeployTestnet is Script {
    // Contract instances
    CrossChainBridge public bridge;
    Fill2FeeToken public token;
    CrossChainMessenger public messenger;
    SecurityManager public securityManager;
    
    // Testnet configuration
    uint256 public constant TEST_TOKEN_SUPPLY = 10000000 * 10**18; // 10M tokens for testing
    uint256 public constant TEST_BRIDGE_BALANCE = 100 ether;
    
    // Test addresses for different scenarios
    address[] public testUsers = [
        0x1234567890123456789012345678901234567890,
        0x2345678901234567890123456789012345678901,
        0x3456789012345678901234567890123456789012
    ];
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying testnet contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy all contracts
        _deployContracts();
        
        // Configure for testnet
        _configureTestnet();
        
        // Setup test scenarios
        _setupTestScenarios();
        
        vm.stopBroadcast();
        
        // Display testnet summary
        _displayTestnetSummary();
    }
    
    function _deployContracts() internal {
        console.log("\n=== Deploying Testnet Contracts ===");
        
        // Deploy SecurityManager
        securityManager = new SecurityManager();
        console.log("SecurityManager deployed at:", address(securityManager));
        
        // Deploy Fill2FeeToken
        token = new Fill2FeeToken();
        console.log("Fill2FeeToken deployed at:", address(token));
        
        // Deploy CrossChainMessenger
        messenger = new CrossChainMessenger();
        console.log("CrossChainMessenger deployed at:", address(messenger));
        
        // Deploy CrossChainBridge
        bridge = new CrossChainBridge();
        console.log("CrossChainBridge deployed at:", address(bridge));
    }
    
    function _configureTestnet() internal {
        console.log("\n=== Configuring Testnet ===");
        
        // Set bridge contract in token
        token.setBridgeContract(address(bridge));
        
        // Set bridge contract in messenger
        messenger.setBridgeContract(block.chainid, address(bridge));
        
        // Add testnet chains (Goerli, Mumbai, BSC Testnet)
        bridge.addSupportedChain(5); // Goerli
        bridge.addSupportedChain(80001); // Mumbai (Polygon testnet)
        bridge.addSupportedChain(97); // BSC Testnet
        
        // Configure relaxed security for testing
        securityManager.setSecurityConfig(
            1000 ether,   // max daily volume (higher for testing)
            100 ether,    // max single transfer (higher for testing)
            0.0001 ether, // min transfer amount (lower for testing)
            5 minutes     // cooldown period (shorter for testing)
        );
        
        console.log("Testnet configuration completed");
    }
    
    function _setupTestScenarios() internal {
        console.log("\n=== Setting Up Test Scenarios ===");
        
        // Fund bridge with test ETH
        (bool success, ) = address(bridge).call{value: TEST_BRIDGE_BALANCE}("");
        require(success, "Failed to fund bridge");
        console.log("Bridge funded with:", TEST_BRIDGE_BALANCE, "ETH");
        
        // Distribute test tokens to test users
        for (uint256 i = 0; i < testUsers.length; i++) {
            uint256 amount = 1000 * 10**18; // 1000 tokens per user
            token.mint(testUsers[i], amount);
            console.log("Minted", amount, "tokens for test user:", testUsers[i]);
        }
        
        // Add some test users to whitelist
        securityManager.addToWhitelist(testUsers[0]);
        console.log("Added test user to whitelist:", testUsers[0]);
        
        // Add a test user to blacklist for testing
        securityManager.addToBlacklist(testUsers[2]);
        console.log("Added test user to blacklist:", testUsers[2]);
    }
    
    function _displayTestnetSummary() internal view {
        console.log("\n=== TESTNET DEPLOYMENT SUMMARY ===");
        console.log("SecurityManager:", address(securityManager));
        console.log("Fill2FeeToken:", address(token));
        console.log("CrossChainMessenger:", address(messenger));
        console.log("CrossChainBridge:", address(bridge));
        console.log("Bridge balance:", address(bridge).balance);
        console.log("Token total supply:", token.totalSupply());
        console.log("Test users configured:", testUsers.length);
        console.log("Testnet deployment completed successfully!");
        console.log("\n=== TEST SCENARIOS READY ===");
        console.log("1. Normal transfers with whitelisted user");
        console.log("2. Blacklisted user transfers (should fail)");
        console.log("3. Rate limiting tests");
        console.log("4. Cross-chain message passing");
        console.log("5. Security alert testing");
    }
}

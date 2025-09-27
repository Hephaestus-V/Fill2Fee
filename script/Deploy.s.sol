// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/CrossChainBridge.sol";
import "../src/Fill2FeeToken.sol";
import "../src/CrossChainMessenger.sol";
import "../src/SecurityManager.sol";

/**
 * @title Deploy
 * @dev Deployment script for Fill2Fee cross-chain bridge system
 * @author Fill2Fee Team
 */
contract Deploy is Script {
    // Contract instances
    CrossChainBridge public bridge;
    Fill2FeeToken public token;
    CrossChainMessenger public messenger;
    SecurityManager public securityManager;
    
    // Deployment configuration
    uint256 public constant INITIAL_TOKEN_SUPPLY = 1000000 * 10**18; // 1M tokens
    uint256 public constant BRIDGE_INITIAL_BALANCE = 10 ether;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);
        console.log("Block timestamp:", block.timestamp);
        console.log("Block number:", block.number);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy SecurityManager first
        console.log("\n=== Deploying SecurityManager ===");
        securityManager = new SecurityManager();
        console.log("SecurityManager deployed at:", address(securityManager));
        
        // Deploy Fill2FeeToken
        console.log("\n=== Deploying Fill2FeeToken ===");
        token = new Fill2FeeToken();
        console.log("Fill2FeeToken deployed at:", address(token));
        console.log("Initial supply:", token.totalSupply());
        
        // Deploy CrossChainMessenger
        console.log("\n=== Deploying CrossChainMessenger ===");
        messenger = new CrossChainMessenger();
        console.log("CrossChainMessenger deployed at:", address(messenger));
        
        // Deploy CrossChainBridge
        console.log("\n=== Deploying CrossChainBridge ===");
        bridge = new CrossChainBridge();
        console.log("CrossChainBridge deployed at:", address(bridge));
        
        // Configure the system
        console.log("\n=== Configuring System ===");
        _configureSystem();
        
        // Fund the bridge with initial ETH
        console.log("\n=== Funding Bridge ===");
        _fundBridge();
        
        vm.stopBroadcast();
        
        // Display deployment summary
        _displayDeploymentSummary();
    }
    
    function _configureSystem() internal {
        // Set bridge contract in token
        token.setBridgeContract(address(bridge));
        console.log("Bridge contract set in token");
        
        // Set bridge contract in messenger
        messenger.setBridgeContract(block.chainid, address(bridge));
        console.log("Bridge contract set in messenger");
        
        // Add supported chains (example: Ethereum mainnet, Polygon, BSC)
        bridge.addSupportedChain(1); // Ethereum mainnet
        bridge.addSupportedChain(137); // Polygon
        bridge.addSupportedChain(56); // BSC
        console.log("Supported chains configured");
        
        // Configure security settings
        securityManager.setSecurityConfig(
            100 ether,    // max daily volume
            10 ether,    // max single transfer
            0.001 ether, // min transfer amount
            1 hours      // cooldown period
        );
        console.log("Security configuration set");
    }
    
    function _fundBridge() internal {
        // Send initial ETH to bridge
        (bool success, ) = address(bridge).call{value: BRIDGE_INITIAL_BALANCE}("");
        require(success, "Failed to fund bridge");
        console.log("Bridge funded with:", BRIDGE_INITIAL_BALANCE, "ETH");
    }
    
    function _displayDeploymentSummary() internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("SecurityManager:", address(securityManager));
        console.log("Fill2FeeToken:", address(token));
        console.log("CrossChainMessenger:", address(messenger));
        console.log("CrossChainBridge:", address(bridge));
        console.log("Bridge balance:", address(bridge).balance);
        console.log("Token total supply:", token.totalSupply());
        console.log("Deployment completed successfully!");
    }
}

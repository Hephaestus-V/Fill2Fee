// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";

/**
 * @title SecurityManager
 * @dev Comprehensive security mechanisms for cross-chain bridge
 * @author Fill2Fee Team
 */
contract SecurityManager {
    // Events
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
    
    event SuspiciousActivity(
        address indexed user,
        string activity,
        uint256 timestamp
    );

    // Structs
    struct SecurityConfig {
        uint256 maxDailyVolume;
        uint256 maxSingleTransfer;
        uint256 minTransferAmount;
        uint256 cooldownPeriod;
        bool emergencyPause;
        bool maintenanceMode;
    }
    
    struct UserLimits {
        uint256 dailyVolume;
        uint256 lastTransferTime;
        uint256 transferCount;
        bool isBlacklisted;
        uint256 cooldownEnd;
    }

    // State variables
    mapping(address => UserLimits) public userLimits;
    mapping(address => bool) public blacklistedAddresses;
    mapping(address => bool) public whitelistedAddresses;
    mapping(bytes32 => bool) public processedTransactions;
    
    SecurityConfig public securityConfig;
    address public owner;
    address public securityAdmin;
    uint256 public totalAlerts;
    uint256 public emergencyPauseTime;
    
    // Constants
    uint256 public constant MAX_DAILY_VOLUME = 1000 ether;
    uint256 public constant MAX_SINGLE_TRANSFER = 100 ether;
    uint256 public constant MIN_TRANSFER_AMOUNT = 0.001 ether;
    uint256 public constant COOLDOWN_PERIOD = 1 hours;
    uint256 public constant SEVERITY_LOW = 1;
    uint256 public constant SEVERITY_MEDIUM = 2;
    uint256 public constant SEVERITY_HIGH = 3;
    uint256 public constant SEVERITY_CRITICAL = 4;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlySecurityAdmin() {
        require(
            msg.sender == owner || msg.sender == securityAdmin,
            "Only security admin can call this function"
        );
        _;
    }
    
    modifier notBlacklisted(address user) {
        require(!blacklistedAddresses[user], "Address is blacklisted");
        _;
    }
    
    modifier notInEmergency() {
        require(!securityConfig.emergencyPause, "System is in emergency pause");
        _;
    }
    
    modifier notInMaintenance() {
        require(!securityConfig.maintenanceMode, "System is in maintenance mode");
        _;
    }

    constructor() {
        owner = msg.sender;
        securityAdmin = msg.sender;
        
        securityConfig = SecurityConfig({
            maxDailyVolume: MAX_DAILY_VOLUME,
            maxSingleTransfer: MAX_SINGLE_TRANSFER,
            minTransferAmount: MIN_TRANSFER_AMOUNT,
            cooldownPeriod: COOLDOWN_PERIOD,
            emergencyPause: false,
            maintenanceMode: false
        });
    }

    /**
     * @dev Validate a transfer request
     * @param user User address
     * @param amount Transfer amount
     * @param targetChainId Target chain ID
     * @return isValid Whether the transfer is valid
     * @return reason Reason for rejection if invalid
     */
    function validateTransfer(
        address user,
        uint256 amount,
        uint256 targetChainId
    ) external view returns (bool isValid, string memory reason) {
        // Check if system is paused
        if (securityConfig.emergencyPause) {
            return (false, "System is in emergency pause");
        }
        
        if (securityConfig.maintenanceMode) {
            return (false, "System is in maintenance mode");
        }
        
        // Check if user is blacklisted
        if (blacklistedAddresses[user]) {
            return (false, "User is blacklisted");
        }
        
        // Check minimum transfer amount
        if (amount < securityConfig.minTransferAmount) {
            return (false, "Amount below minimum threshold");
        }
        
        // Check maximum single transfer
        if (amount > securityConfig.maxSingleTransfer) {
            return (false, "Amount exceeds maximum single transfer");
        }
        
        // Check daily volume limits
        UserLimits memory limits = userLimits[user];
        if (limits.dailyVolume + amount > securityConfig.maxDailyVolume) {
            return (false, "Daily volume limit exceeded");
        }
        
        // Check cooldown period
        if (block.timestamp < limits.cooldownEnd) {
            return (false, "Transfer cooldown period active");
        }
        
        return (true, "Transfer validated");
    }

    /**
     * @dev Record a transfer for security tracking
     * @param user User address
     * @param amount Transfer amount
     * @param targetChainId Target chain ID
     * @param txHash Transaction hash
     */
    function recordTransfer(
        address user,
        uint256 amount,
        uint256 targetChainId,
        bytes32 txHash
    ) external onlySecurityAdmin {
        require(!processedTransactions[txHash], "Transaction already processed");
        
        processedTransactions[txHash] = true;
        
        UserLimits storage limits = userLimits[user];
        limits.dailyVolume += amount;
        limits.lastTransferTime = block.timestamp;
        limits.transferCount += 1;
        limits.cooldownEnd = block.timestamp + securityConfig.cooldownPeriod;
        
        // Check for suspicious patterns
        _checkSuspiciousActivity(user, amount, targetChainId);
        
        console.log("Transfer recorded for user:", user);
        console.log("Amount:", amount);
        console.log("Daily volume:", limits.dailyVolume);
    }

    /**
     * @dev Check for suspicious activity patterns
     * @param user User address
     * @param amount Transfer amount
     * @param targetChainId Target chain ID
     */
    function _checkSuspiciousActivity(
        address user,
        uint256 amount,
        uint256 targetChainId
    ) internal {
        UserLimits memory limits = userLimits[user];
        
        // Check for rapid successive transfers
        if (limits.transferCount > 10 && 
            block.timestamp - limits.lastTransferTime < 1 hours) {
            _triggerAlert("RAPID_TRANSFERS", user, SEVERITY_MEDIUM, 
                "User making rapid successive transfers");
        }
        
        // Check for large amount transfers
        if (amount > securityConfig.maxSingleTransfer * 0.8) {
            _triggerAlert("LARGE_TRANSFER", user, SEVERITY_HIGH, 
                "Large transfer detected");
        }
        
        // Check for unusual chain patterns
        if (targetChainId == 0 || targetChainId > 1000000) {
            _triggerAlert("UNUSUAL_CHAIN", user, SEVERITY_MEDIUM, 
                "Transfer to unusual chain ID");
        }
    }

    /**
     * @dev Trigger a security alert
     * @param alertType Type of alert
     * @param target Target address
     * @param severity Alert severity
     * @param message Alert message
     */
    function _triggerAlert(
        string memory alertType,
        address target,
        uint256 severity,
        string memory message
    ) internal {
        totalAlerts++;
        
        emit SecurityAlert(alertType, target, severity, message);
        emit SuspiciousActivity(target, alertType, block.timestamp);
        
        console.log("Security alert triggered:");
        console.log("Type:", alertType);
        console.log("Target:", target);
        console.log("Severity:", severity);
        console.log("Message:", message);
    }

    /**
     * @dev Add address to blacklist
     * @param addr Address to blacklist
     */
    function addToBlacklist(address addr) external onlySecurityAdmin {
        require(addr != address(0), "Invalid address");
        require(!blacklistedAddresses[addr], "Address already blacklisted");
        
        blacklistedAddresses[addr] = true;
        userLimits[addr].isBlacklisted = true;
        
        _triggerAlert("BLACKLIST_ADD", addr, SEVERITY_HIGH, "Address added to blacklist");
        
        console.log("Address blacklisted:", addr);
    }

    /**
     * @dev Remove address from blacklist
     * @param addr Address to remove from blacklist
     */
    function removeFromBlacklist(address addr) external onlySecurityAdmin {
        require(blacklistedAddresses[addr], "Address not blacklisted");
        
        blacklistedAddresses[addr] = false;
        userLimits[addr].isBlacklisted = false;
        
        console.log("Address removed from blacklist:", addr);
    }

    /**
     * @dev Add address to whitelist
     * @param addr Address to whitelist
     */
    function addToWhitelist(address addr) external onlySecurityAdmin {
        require(addr != address(0), "Invalid address");
        require(!whitelistedAddresses[addr], "Address already whitelisted");
        
        whitelistedAddresses[addr] = true;
        
        console.log("Address whitelisted:", addr);
    }

    /**
     * @dev Remove address from whitelist
     * @param addr Address to remove from whitelist
     */
    function removeFromWhitelist(address addr) external onlySecurityAdmin {
        require(whitelistedAddresses[addr], "Address not whitelisted");
        
        whitelistedAddresses[addr] = false;
        
        console.log("Address removed from whitelist:", addr);
    }

    /**
     * @dev Set security configuration
     * @param maxDailyVolume Maximum daily volume per user
     * @param maxSingleTransfer Maximum single transfer amount
     * @param minTransferAmount Minimum transfer amount
     * @param cooldownPeriod Cooldown period between transfers
     */
    function setSecurityConfig(
        uint256 maxDailyVolume,
        uint256 maxSingleTransfer,
        uint256 minTransferAmount,
        uint256 cooldownPeriod
    ) external onlySecurityAdmin {
        require(maxDailyVolume > 0, "Max daily volume must be positive");
        require(maxSingleTransfer > 0, "Max single transfer must be positive");
        require(minTransferAmount > 0, "Min transfer amount must be positive");
        require(cooldownPeriod > 0, "Cooldown period must be positive");
        
        securityConfig.maxDailyVolume = maxDailyVolume;
        securityConfig.maxSingleTransfer = maxSingleTransfer;
        securityConfig.minTransferAmount = minTransferAmount;
        securityConfig.cooldownPeriod = cooldownPeriod;
        
        console.log("Security configuration updated");
    }

    /**
     * @dev Enable emergency pause
     */
    function enableEmergencyPause() external onlySecurityAdmin {
        require(!securityConfig.emergencyPause, "Emergency pause already active");
        
        securityConfig.emergencyPause = true;
        emergencyPauseTime = block.timestamp;
        
        _triggerAlert("EMERGENCY_PAUSE", address(0), SEVERITY_CRITICAL, 
            "Emergency pause activated");
        
        console.log("Emergency pause activated");
    }

    /**
     * @dev Disable emergency pause
     */
    function disableEmergencyPause() external onlyOwner {
        require(securityConfig.emergencyPause, "Emergency pause not active");
        
        securityConfig.emergencyPause = false;
        
        console.log("Emergency pause deactivated");
    }

    /**
     * @dev Enable maintenance mode
     */
    function enableMaintenanceMode() external onlySecurityAdmin {
        require(!securityConfig.maintenanceMode, "Maintenance mode already active");
        
        securityConfig.maintenanceMode = true;
        
        console.log("Maintenance mode activated");
    }

    /**
     * @dev Disable maintenance mode
     */
    function disableMaintenanceMode() external onlySecurityAdmin {
        require(securityConfig.maintenanceMode, "Maintenance mode not active");
        
        securityConfig.maintenanceMode = false;
        
        console.log("Maintenance mode deactivated");
    }

    /**
     * @dev Reset user daily limits (for testing or admin purposes)
     * @param user User address
     */
    function resetUserLimits(address user) external onlySecurityAdmin {
        userLimits[user].dailyVolume = 0;
        userLimits[user].transferCount = 0;
        userLimits[user].cooldownEnd = 0;
        
        console.log("User limits reset for:", user);
    }

    /**
     * @dev Get user security status
     * @param user User address
     * @return limits User limits
     * @return isBlacklisted Whether user is blacklisted
     * @return isWhitelisted Whether user is whitelisted
     */
    function getUserSecurityStatus(address user) external view returns (
        UserLimits memory limits,
        bool isBlacklisted,
        bool isWhitelisted
    ) {
        return (
            userLimits[user],
            blacklistedAddresses[user],
            whitelistedAddresses[user]
        );
    }

    /**
     * @dev Get security statistics
     * @return totalAlerts_ Total number of alerts
     * @return emergencyPauseTime_ Time when emergency pause was activated
     * @return config Current security configuration
     */
    function getSecurityStats() external view returns (
        uint256 totalAlerts_,
        uint256 emergencyPauseTime_,
        SecurityConfig memory config
    ) {
        return (totalAlerts, emergencyPauseTime, securityConfig);
    }
}

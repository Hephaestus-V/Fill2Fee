// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";

/**
 * @title CrossChainBridge
 * @dev A bridge contract for transferring funds between different chains
 * @author Fill2Fee Team
 */
contract CrossChainBridge {
    // Events
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
    
    event BridgeInitialized(
        uint256 indexed chainId,
        address indexed bridgeAddress
    );

    // State variables
    mapping(uint256 => bool) public supportedChains;
    mapping(bytes32 => bool) public processedDeposits;
    mapping(address => uint256) public balances;
    
    address public owner;
    uint256 public currentChainId;
    uint256 public totalDeposits;
    uint256 public totalWithdrawals;
    
    // Constants
    uint256 public constant MIN_DEPOSIT = 0.001 ether;
    uint256 public constant MAX_DEPOSIT = 100 ether;
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlySupportedChain(uint256 chainId) {
        require(supportedChains[chainId], "Chain not supported");
        _;
    }
    
    modifier validDeposit() {
        require(msg.value >= MIN_DEPOSIT, "Deposit too small");
        require(msg.value <= MAX_DEPOSIT, "Deposit too large");
        _;
    }

    constructor() {
        owner = msg.sender;
        currentChainId = block.chainid;
        supportedChains[currentChainId] = true;
        
        emit BridgeInitialized(currentChainId, address(this));
    }

    /**
     * @dev Add support for a new chain
     * @param chainId The chain ID to support
     */
    function addSupportedChain(uint256 chainId) external onlyOwner {
        require(chainId != currentChainId, "Cannot add current chain");
        supportedChains[chainId] = true;
    }

    /**
     * @dev Remove support for a chain
     * @param chainId The chain ID to remove support for
     */
    function removeSupportedChain(uint256 chainId) external onlyOwner {
        require(chainId != currentChainId, "Cannot remove current chain");
        supportedChains[chainId] = false;
    }

    /**
     * @dev Initiate a cross-chain deposit
     * @param targetChainId The destination chain ID
     * @return depositId Unique identifier for this deposit
     */
    function initiateDeposit(uint256 targetChainId) 
        external 
        payable 
        onlySupportedChain(targetChainId)
        validDeposit
        returns (bytes32 depositId) 
    {
        require(targetChainId != currentChainId, "Cannot deposit to same chain");
        
        depositId = keccak256(abi.encodePacked(
            msg.sender,
            targetChainId,
            msg.value,
            block.timestamp,
            block.number
        ));
        
        require(!processedDeposits[depositId], "Deposit already processed");
        
        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;
        processedDeposits[depositId] = true;
        
        emit DepositInitiated(msg.sender, targetChainId, msg.value, depositId);
        
        console.log("Deposit initiated:", uint256(depositId));
        console.log("Amount:", msg.value);
        console.log("Target chain:", targetChainId);
    }

    /**
     * @dev Complete a cross-chain withdrawal
     * @param user The user to withdraw to
     * @param amount The amount to withdraw
     * @param depositId The original deposit ID
     * @param sourceChainId The source chain ID
     */
    function completeWithdrawal(
        address user,
        uint256 amount,
        bytes32 depositId,
        uint256 sourceChainId
    ) external onlyOwner {
        require(!processedDeposits[depositId], "Withdrawal already processed");
        require(address(this).balance >= amount, "Insufficient bridge balance");
        require(amount > 0, "Amount must be positive");
        
        processedDeposits[depositId] = true;
        totalWithdrawals += amount;
        
        (bool success, ) = user.call{value: amount}("");
        require(success, "Withdrawal transfer failed");
        
        emit WithdrawalCompleted(user, sourceChainId, amount, depositId);
        
        console.log("Withdrawal completed for user:", user);
        console.log("Amount:", amount);
        console.log("Source chain:", sourceChainId);
    }

    /**
     * @dev Get bridge statistics
     * @return totalDeposits_ Total deposits made
     * @return totalWithdrawals_ Total withdrawals made
     * @return bridgeBalance Current bridge balance
     */
    function getBridgeStats() external view returns (
        uint256 totalDeposits_,
        uint256 totalWithdrawals_,
        uint256 bridgeBalance
    ) {
        return (totalDeposits, totalWithdrawals, address(this).balance);
    }

    /**
     * @dev Check if a deposit has been processed
     * @param depositId The deposit ID to check
     * @return processed Whether the deposit has been processed
     */
    function isDepositProcessed(bytes32 depositId) external view returns (bool processed) {
        return processedDeposits[depositId];
    }

    /**
     * @dev Emergency withdrawal function for owner
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        require(amount > 0, "Amount must be positive");
        
        (bool success, ) = owner.call{value: amount}("");
        require(success, "Emergency withdrawal failed");
    }

    /**
     * @dev Receive function to accept ETH deposits
     */
    receive() external payable {
        // Allow direct ETH deposits
    }
}

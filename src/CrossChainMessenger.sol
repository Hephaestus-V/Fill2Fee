// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";

/**
 * @title CrossChainMessenger
 * @dev Handles cross-chain message passing and validation
 * @author Fill2Fee Team
 */
contract CrossChainMessenger {
    // Events
    event MessageSent(
        uint256 indexed sourceChainId,
        uint256 indexed targetChainId,
        bytes32 indexed messageId,
        address sender,
        bytes payload
    );
    
    event MessageReceived(
        uint256 indexed sourceChainId,
        bytes32 indexed messageId,
        bool success
    );
    
    event ValidatorAdded(address indexed validator);
    event ValidatorRemoved(address indexed validator);

    // Structs
    struct CrossChainMessage {
        uint256 sourceChainId;
        uint256 targetChainId;
        address sender;
        bytes payload;
        uint256 timestamp;
        bool processed;
        bytes32 messageId;
    }

    // State variables
    mapping(bytes32 => CrossChainMessage) public messages;
    mapping(address => bool) public validators;
    mapping(uint256 => address) public bridgeContracts;
    
    address public owner;
    uint256 public currentChainId;
    uint256 public validatorThreshold;
    uint256 public messageTimeout;
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyValidator() {
        require(validators[msg.sender], "Only validators can call this function");
        _;
    }
    
    modifier onlyBridge() {
        require(bridgeContracts[msg.sender] != address(0), "Only bridge contracts can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        currentChainId = block.chainid;
        validatorThreshold = 1; // Minimum validators required
        messageTimeout = 24 hours; // Message timeout period
        
        // Add owner as initial validator
        validators[owner] = true;
        emit ValidatorAdded(owner);
    }

    /**
     * @dev Send a cross-chain message
     * @param targetChainId Destination chain ID
     * @param payload Message payload
     * @return messageId Unique message identifier
     */
    function sendMessage(uint256 targetChainId, bytes calldata payload) 
        external 
        onlyBridge 
        returns (bytes32 messageId) 
    {
        require(targetChainId != currentChainId, "Cannot send to same chain");
        require(payload.length > 0, "Payload cannot be empty");
        
        messageId = keccak256(abi.encodePacked(
            currentChainId,
            targetChainId,
            msg.sender,
            payload,
            block.timestamp,
            block.number
        ));
        
        require(messages[messageId].messageId == bytes32(0), "Message already exists");
        
        messages[messageId] = CrossChainMessage({
            sourceChainId: currentChainId,
            targetChainId: targetChainId,
            sender: msg.sender,
            payload: payload,
            timestamp: block.timestamp,
            processed: false,
            messageId: messageId
        });
        
        emit MessageSent(currentChainId, targetChainId, messageId, msg.sender, payload);
        
        console.log("Cross-chain message sent:");
        console.log("Message ID:", uint256(messageId));
        console.log("Target chain:", targetChainId);
        console.log("Payload length:", payload.length);
    }

    /**
     * @dev Receive and process a cross-chain message
     * @param sourceChainId Source chain ID
     * @param messageId Message identifier
     * @param sender Original sender address
     * @param payload Message payload
     * @param timestamp Message timestamp
     * @return success Whether the message was processed successfully
     */
    function receiveMessage(
        uint256 sourceChainId,
        bytes32 messageId,
        address sender,
        bytes calldata payload,
        uint256 timestamp
    ) external onlyValidator returns (bool success) {
        require(sourceChainId != currentChainId, "Cannot receive from same chain");
        require(messages[messageId].messageId == bytes32(0), "Message already processed");
        require(block.timestamp - timestamp <= messageTimeout, "Message timeout");
        
        // Validate message integrity
        bytes32 expectedMessageId = keccak256(abi.encodePacked(
            sourceChainId,
            currentChainId,
            sender,
            payload,
            timestamp,
            block.number - 1 // Allow for some block variance
        ));
        
        require(messageId == expectedMessageId, "Invalid message ID");
        
        messages[messageId] = CrossChainMessage({
            sourceChainId: sourceChainId,
            targetChainId: currentChainId,
            sender: sender,
            payload: payload,
            timestamp: timestamp,
            processed: true,
            messageId: messageId
        });
        
        // Process the message payload
        success = _processMessage(sourceChainId, sender, payload);
        
        emit MessageReceived(sourceChainId, messageId, success);
        
        console.log("Cross-chain message received:");
        console.log("Message ID:", uint256(messageId));
        console.log("Source chain:", sourceChainId);
        console.log("Success:", success);
    }

    /**
     * @dev Process the message payload
     * @param sourceChainId Source chain ID
     * @param sender Original sender address
     * @param payload Message payload
     * @return success Whether processing was successful
     */
    function _processMessage(
        uint256 sourceChainId,
        address sender,
        bytes calldata payload
    ) internal returns (bool success) {
        // Decode the payload and execute the appropriate action
        // This is a simplified version - in production, you'd have more complex logic
        
        if (payload.length >= 4) {
            bytes4 selector = bytes4(payload[0:4]);
            
            if (selector == bytes4(keccak256("completeWithdrawal(address,uint256,bytes32,uint256)"))) {
                // Handle withdrawal completion
                (address user, uint256 amount, bytes32 depositId, uint256 originalChainId) = 
                    abi.decode(payload[4:], (address, uint256, bytes32, uint256));
                
                // Forward to bridge contract
                address bridgeContract = bridgeContracts[msg.sender];
                if (bridgeContract != address(0)) {
                    (bool callSuccess, ) = bridgeContract.call(payload);
                    success = callSuccess;
                }
            } else {
                // Handle other message types
                success = true;
            }
        } else {
            success = false;
        }
        
        return success;
    }

    /**
     * @dev Add a validator
     * @param validator Address of the validator to add
     */
    function addValidator(address validator) external onlyOwner {
        require(validator != address(0), "Invalid validator address");
        require(!validators[validator], "Validator already exists");
        
        validators[validator] = true;
        emit ValidatorAdded(validator);
        
        console.log("Validator added:", validator);
    }

    /**
     * @dev Remove a validator
     * @param validator Address of the validator to remove
     */
    function removeValidator(address validator) external onlyOwner {
        require(validators[validator], "Validator does not exist");
        require(validator != owner, "Cannot remove owner");
        
        validators[validator] = false;
        emit ValidatorRemoved(validator);
        
        console.log("Validator removed:", validator);
    }

    /**
     * @dev Set bridge contract for a chain
     * @param chainId Chain ID
     * @param bridgeContract Bridge contract address
     */
    function setBridgeContract(uint256 chainId, address bridgeContract) external onlyOwner {
        require(bridgeContract != address(0), "Invalid bridge address");
        bridgeContracts[chainId] = bridgeContract;
        
        console.log("Bridge contract set for chain", chainId, ":", bridgeContract);
    }

    /**
     * @dev Set validator threshold
     * @param threshold New threshold value
     */
    function setValidatorThreshold(uint256 threshold) external onlyOwner {
        require(threshold > 0, "Threshold must be positive");
        validatorThreshold = threshold;
        
        console.log("Validator threshold set to:", threshold);
    }

    /**
     * @dev Set message timeout
     * @param timeout New timeout value in seconds
     */
    function setMessageTimeout(uint256 timeout) external onlyOwner {
        require(timeout > 0, "Timeout must be positive");
        messageTimeout = timeout;
        
        console.log("Message timeout set to:", timeout);
    }

    /**
     * @dev Get message details
     * @param messageId Message identifier
     * @return message Message details
     */
    function getMessage(bytes32 messageId) external view returns (CrossChainMessage memory message) {
        return messages[messageId];
    }

    /**
     * @dev Check if address is a validator
     * @param addr Address to check
     * @return isValidator Whether the address is a validator
     */
    function isValidator(address addr) external view returns (bool isValidator) {
        return validators[addr];
    }

    /**
     * @dev Get bridge contract for a chain
     * @param chainId Chain ID
     * @return bridgeContract Bridge contract address
     */
    function getBridgeContract(uint256 chainId) external view returns (address bridgeContract) {
        return bridgeContracts[chainId];
    }
}

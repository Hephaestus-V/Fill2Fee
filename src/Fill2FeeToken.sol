// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";

/**
 * @title Fill2FeeToken
 * @dev ERC20 token for testing cross-chain bridge functionality
 * @author Fill2Fee Team
 */
contract Fill2FeeToken {
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    // Token metadata
    string public name = "Fill2Fee Token";
    string public symbol = "F2F";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    // Mappings
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Access control
    address public owner;
    address public bridgeContract;
    bool public bridgeEnabled;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyBridge() {
        require(msg.sender == bridgeContract && bridgeEnabled, "Only bridge can call this function");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    constructor() {
        owner = msg.sender;
        bridgeEnabled = false;
        
        // Mint initial supply to owner
        uint256 initialSupply = 1000000 * 10**decimals; // 1M tokens
        totalSupply = initialSupply;
        balanceOf[owner] = initialSupply;
        
        emit Transfer(address(0), owner, initialSupply);
        console.log("Fill2FeeToken deployed with initial supply:", initialSupply);
    }

    /**
     * @dev Set the bridge contract address
     * @param _bridgeContract Address of the bridge contract
     */
    function setBridgeContract(address _bridgeContract) external onlyOwner validAddress(_bridgeContract) {
        bridgeContract = _bridgeContract;
        bridgeEnabled = true;
        console.log("Bridge contract set to:", _bridgeContract);
    }

    /**
     * @dev Disable bridge functionality
     */
    function disableBridge() external onlyOwner {
        bridgeEnabled = false;
        console.log("Bridge functionality disabled");
    }

    /**
     * @dev Standard ERC20 transfer function
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return success Whether the transfer was successful
     */
    function transfer(address to, uint256 amount) external validAddress(to) returns (bool success) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @dev Standard ERC20 transferFrom function
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return success Whether the transfer was successful
     */
    function transferFrom(address from, address to, uint256 amount) external validAddress(to) returns (bool success) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Standard ERC20 approve function
     * @param spender Address to approve
     * @param amount Amount to approve
     * @return success Whether the approval was successful
     */
    function approve(address spender, uint256 amount) external validAddress(spender) returns (bool success) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Mint tokens (bridge functionality)
     * @param to Address to mint tokens to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyBridge validAddress(to) {
        require(amount > 0, "Amount must be positive");
        
        totalSupply += amount;
        balanceOf[to] += amount;
        
        emit Mint(to, amount);
        emit Transfer(address(0), to, amount);
        
        console.log("Minted", amount, "tokens to", to);
    }

    /**
     * @dev Burn tokens (bridge functionality)
     * @param from Address to burn tokens from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external onlyBridge {
        require(amount > 0, "Amount must be positive");
        require(balanceOf[from] >= amount, "Insufficient balance");
        
        totalSupply -= amount;
        balanceOf[from] -= amount;
        
        emit Burn(from, amount);
        emit Transfer(from, address(0), amount);
        
        console.log("Burned", amount, "tokens from", from);
    }

    /**
     * @dev Cross-chain lock function (for bridge)
     * @param from Address to lock tokens from
     * @param amount Amount to lock
     */
    function lockForBridge(address from, uint256 amount) external onlyBridge {
        require(amount > 0, "Amount must be positive");
        require(balanceOf[from] >= amount, "Insufficient balance");
        
        balanceOf[from] -= amount;
        balanceOf[bridgeContract] += amount;
        
        emit Transfer(from, bridgeContract, amount);
        console.log("Locked", amount, "tokens for bridge from", from);
    }

    /**
     * @dev Cross-chain unlock function (for bridge)
     * @param to Address to unlock tokens to
     * @param amount Amount to unlock
     */
    function unlockFromBridge(address to, uint256 amount) external onlyBridge validAddress(to) {
        require(amount > 0, "Amount must be positive");
        require(balanceOf[bridgeContract] >= amount, "Insufficient bridge balance");
        
        balanceOf[bridgeContract] -= amount;
        balanceOf[to] += amount;
        
        emit Transfer(bridgeContract, to, amount);
        console.log("Unlocked", amount, "tokens from bridge to", to);
    }

    /**
     * @dev Get token information
     * @return name_ Token name
     * @return symbol_ Token symbol
     * @return decimals_ Token decimals
     * @return totalSupply_ Total supply
     */
    function getTokenInfo() external view returns (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_
    ) {
        return (name, symbol, decimals, totalSupply);
    }

    /**
     * @dev Emergency function to recover accidentally sent tokens
     * @param tokenAddress Address of the token to recover
     * @param amount Amount to recover
     */
    function emergencyRecover(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(this), "Cannot recover own tokens");
        require(amount > 0, "Amount must be positive");
        
        // This would need to be implemented based on the specific token interface
        console.log("Emergency recovery initiated for token:", tokenAddress);
    }
}

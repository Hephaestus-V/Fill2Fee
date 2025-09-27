# Fill2Fee - Cross-Chain Bridge System

A comprehensive cross-chain bridge system built with Solidity and Foundry, enabling secure fund transfers between different blockchain networks.

## 🚀 Features

- **Cross-Chain Transfers**: Seamless fund transfers between different blockchain networks
- **Security-First Design**: Multi-layered security mechanisms with rate limiting and validation
- **Message Passing**: Robust cross-chain communication system
- **Token Support**: ERC20 token integration with bridge functionality
- **Emergency Controls**: Emergency pause and maintenance mode capabilities
- **Comprehensive Testing**: Extensive test coverage with fuzz testing

## 📋 Architecture

### Core Contracts

1. **CrossChainBridge.sol** - Main bridge contract handling deposits and withdrawals
2. **Fill2FeeToken.sol** - ERC20 token with bridge integration capabilities
3. **CrossChainMessenger.sol** - Cross-chain message passing and validation
4. **SecurityManager.sol** - Comprehensive security and access control system

### Key Features

- **Deposit Initiation**: Users can initiate cross-chain deposits with validation
- **Withdrawal Completion**: Secure withdrawal processing with integrity checks
- **Message Validation**: Cryptographic message validation across chains
- **Security Monitoring**: Real-time security alerts and suspicious activity detection
- **Access Control**: Role-based permissions and emergency controls

## 🛠️ Installation & Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js (for additional tooling)
- Git

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd Fill2Fee

# Install dependencies
forge install

# Build the project
forge build

# Run tests
forge test

# Run tests with coverage
forge coverage
```

## 🚀 Deployment

### Mainnet Deployment

```bash
# Set your private key
export PRIVATE_KEY="your-private-key"

# Deploy to mainnet
forge script script/Deploy.s.sol --rpc-url <mainnet-rpc> --broadcast --verify
```

### Testnet Deployment

```bash
# Deploy to testnet with test configurations
forge script script/DeployTestnet.s.sol --rpc-url <testnet-rpc> --broadcast --verify
```

## 📖 Usage

### Basic Cross-Chain Transfer

```solidity
// Initiate a deposit to another chain
bytes32 depositId = bridge.initiateDeposit{value: 1 ether}(targetChainId);

// Complete withdrawal on destination chain
bridge.completeWithdrawal(user, amount, depositId, sourceChainId);
```

### Token Operations

```solidity
// Mint tokens for bridge operations
token.mint(user, amount);

// Lock tokens for cross-chain transfer
token.lockForBridge(user, amount);

// Unlock tokens on destination chain
token.unlockFromBridge(user, amount);
```

### Security Management

```solidity
// Add address to blacklist
securityManager.addToBlacklist(maliciousAddress);

// Enable emergency pause
securityManager.enableEmergencyPause();

// Configure security limits
securityManager.setSecurityConfig(
    maxDailyVolume,
    maxSingleTransfer,
    minTransferAmount,
    cooldownPeriod
);
```

## 🔒 Security Features

### Multi-Layer Security

1. **Rate Limiting**: Daily volume and single transfer limits
2. **Cooldown Periods**: Time-based transfer restrictions
3. **Blacklist/Whitelist**: Address-based access control
4. **Emergency Pause**: System-wide emergency controls
5. **Message Validation**: Cryptographic integrity checks
6. **Suspicious Activity Detection**: Automated threat detection

### Security Configuration

```solidity
// Configure security parameters
securityManager.setSecurityConfig(
    100 ether,    // Max daily volume per user
    10 ether,     // Max single transfer
    0.001 ether,  // Min transfer amount
    1 hours       // Cooldown period
);
```

## 🧪 Testing

### Run All Tests

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run specific test file
forge test --match-path test/CrossChainBridge.t.sol
```

### Test Coverage

```bash
# Generate test coverage report
forge coverage

# View coverage report
forge coverage --report lcov
```

### Fuzz Testing

The project includes comprehensive fuzz testing for edge cases:

```bash
# Run fuzz tests
forge test --match-test testFuzz
```

## 📊 Contract Addresses

### Mainnet (Example)
- CrossChainBridge: `0x...`
- Fill2FeeToken: `0x...`
- CrossChainMessenger: `0x...`
- SecurityManager: `0x...`

### Testnet
- CrossChainBridge: `0x...`
- Fill2FeeToken: `0x...`
- CrossChainMessenger: `0x...`
- SecurityManager: `0x...`

## 🔧 Configuration

### Supported Chains

The bridge supports multiple blockchain networks:

- Ethereum Mainnet (Chain ID: 1)
- Polygon (Chain ID: 137)
- BSC (Chain ID: 56)
- Arbitrum (Chain ID: 42161)
- Optimism (Chain ID: 10)

### Adding New Chains

```solidity
// Add support for a new chain
bridge.addSupportedChain(newChainId);
```

## 📈 Monitoring & Analytics

### Bridge Statistics

```solidity
// Get bridge statistics
(uint256 totalDeposits, uint256 totalWithdrawals, uint256 bridgeBalance) = 
    bridge.getBridgeStats();
```

### Security Alerts

The system provides real-time security monitoring:

- Suspicious activity detection
- Rate limit violations
- Emergency pause activations
- Blacklist/whitelist changes

## 🚨 Emergency Procedures

### Emergency Pause

```solidity
// Enable emergency pause (security admin only)
securityManager.enableEmergencyPause();

// Disable emergency pause (owner only)
securityManager.disableEmergencyPause();
```

### Maintenance Mode

```solidity
// Enable maintenance mode
securityManager.enableMaintenanceMode();

// Disable maintenance mode
securityManager.disableMaintenanceMode();
```

## 🔍 API Reference

### CrossChainBridge

- `initiateDeposit(uint256 targetChainId)` - Initiate cross-chain deposit
- `completeWithdrawal(address user, uint256 amount, bytes32 depositId, uint256 sourceChainId)` - Complete withdrawal
- `addSupportedChain(uint256 chainId)` - Add supported chain
- `getBridgeStats()` - Get bridge statistics

### SecurityManager

- `validateTransfer(address user, uint256 amount, uint256 targetChainId)` - Validate transfer
- `addToBlacklist(address addr)` - Add address to blacklist
- `enableEmergencyPause()` - Enable emergency pause
- `setSecurityConfig(...)` - Configure security parameters

### Fill2FeeToken

- `mint(address to, uint256 amount)` - Mint tokens
- `burn(address from, uint256 amount)` - Burn tokens
- `lockForBridge(address from, uint256 amount)` - Lock tokens for bridge
- `unlockFromBridge(address to, uint256 amount)` - Unlock tokens from bridge

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:

- Create an issue in the repository
- Contact the development team
- Check the documentation

## 🔮 Roadmap

- [ ] Multi-signature validation
- [ ] Cross-chain NFT support
- [ ] Advanced analytics dashboard
- [ ] Mobile SDK integration
- [ ] Layer 2 optimization

---

**⚠️ Disclaimer**: This is experimental software. Use at your own risk. Always audit smart contracts before using in production.
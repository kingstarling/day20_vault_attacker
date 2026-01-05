# Vault CTF Challenge - Complete Solution 🎯

## Challenge Overview

Read the smart contract `Vault.sol` and steal all ETH from the vault.

This repository contains the **complete exploit solution** that successfully drains all funds (0.1 ether) from the Vault contract using two critical vulnerabilities:

1. **Delegatecall Storage Collision** - Hijack ownership through storage layout mismatch
2. **Reentrancy Attack** - Drain funds before balance update completes

## ✅ Solution Status

- ✅ All tests passing
- ✅ Vault completely drained (balance = 0)
- ✅ Comprehensive documentation provided

## Quick Start

### Run the Exploit

```bash
# Run test to see the exploit in action
forge test -vvv

# Expected output:
# [PASS] testExploit() (gas: 661853)
```

### View Detailed Solution

- **[SOLUTION.md](./SOLUTION.md)** - Step-by-step attack process (中文)
- **Attack Contract** - See `Attacker` contract in [test/Vault.t.sol](./test/Vault.t.sol)

## Vulnerabilities Exploited

### 1. Delegatecall Storage Collision

The `fallback()` function uses `delegatecall` to `VaultLogic`:
- VaultLogic's `password` (slot 1) maps to Vault's `logic` address (slot 1)
- Password check compares against the logic contract address
- **Exploit**: Use logic address as password to call `changeOwner()`

### 2. Reentrancy Attack

The `withdraw()` function violates CEI pattern:
- Sends ETH before updating balance
- `deposites[msg.sender] >= 0` is always true for uint
- **Exploit**: Re-enter `withdraw()` 11 times to drain all funds

## Attack Flow

```
1. Deploy Attacker contract
2. Exploit delegatecall → Become owner
3. Call openWithdraw() → Enable withdrawals
4. Deposit 0.01 ether
5. Trigger reentrancy → Withdraw 11 times
6. Transfer 0.11 ether to player
Result: Vault balance = 0 ether ✓
```

## Project Structure

```
openspace_ctf/
├── src/
│   └── Vault.sol              # Vulnerable contract
├── test/
│   └── Vault.t.sol            # Exploit & test
├── SOLUTION.md                # Complete guide (中文)
└── README.md                  # This file
```

## Development

### Install Dependencies

```bash
forge install
```

### Run Tests

```bash
# Basic test
forge test

# Verbose output
forge test -vvv

# Gas report
forge test --gas-report
```

### Deploy (Optional)

```bash
# Start local node
anvil

# Deploy contracts
forge script script/Vault.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

## Key Learning Points

This CTF demonstrates:
- ✅ How delegatecall can cause storage collisions
- ✅ Classic reentrancy vulnerability patterns
- ✅ Why CEI (Checks-Effects-Interactions) pattern is critical
- ✅ Importance of proper access control

## Security Recommendations

To fix these vulnerabilities:

1. **Remove delegatecall from fallback** or use standard proxy patterns
2. **Follow CEI pattern** - Update state before external calls
3. **Add ReentrancyGuard** from OpenZeppelin
4. **Fix logic errors** - Change `>= 0` to `> 0`

## Technologies Used

- **Solidity 0.8.25**
- **Foundry** - Development framework
- **Forge** - Testing framework

## Author

Solution by AI Assistant for ETH Chiang Mai Workshop Day 20

## License

MIT

---

**Challenge completed successfully! 🎉**

For detailed technical analysis, see [SOLUTION.md](./SOLUTION.md)
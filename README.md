# Tokenize Vault

A from-scratch implementation of the **ERC-4626 Tokenized Vault Standard** in Solidity, built with **Foundry**.

The project focuses on understanding and implementing the core mechanics of tokenized vaults, including asset/share accounting, exchange-rate calculations, rounding behavior, deposits, withdrawals, minting, redeeming, and protection against the **ERC-4626 inflation/donation attack** using virtual assets and virtual shares.

> **Educational Project**
>
> This project is intended for learning, experimentation, and smart contract security research. It has not been audited and should not be used to manage real funds.

---

## Overview

ERC-4626 standardizes tokenized vault interfaces for protocols that accept an underlying ERC-20 asset and issue shares representing a proportional claim on the vault's assets.

At a high level:

```text
                    ERC-20 Assets
                         │
                         ▼
                   ┌─────────────┐
                   │    Vault    │
                   └─────────────┘
                         │
                         ▼
                    Vault Shares
```

The vault maintains an exchange relationship between **assets** and **shares**.

```text
Assets  ↔  Shares
```

The exchange rate changes as the vault's asset balance and share supply change.

---

## Features

* ERC-4626 tokenized vault implementation
* ERC-20 underlying asset support
* Asset/share conversion
* Deposit and withdrawal functionality
* Mint and redeem functionality
* ERC-4626 preview functions
* Correct rounding direction for conversions
* Virtual asset and virtual share accounting
* Inflation/donation attack mitigation
* Unit testing with Foundry
* Fuzz testing
* Invariant testing
* Security-focused test cases

---

## ERC-4626 Operations

| Operation           | Description                                    |
| ------------------- | ---------------------------------------------- |
| `deposit()`         | Deposits assets and mints shares               |
| `mint()`            | Mints a specified number of shares             |
| `withdraw()`        | Withdraws a specified amount of assets         |
| `redeem()`          | Burns shares and withdraws assets              |
| `convertToShares()` | Converts assets to shares                      |
| `convertToAssets()` | Converts shares to assets                      |
| `previewDeposit()`  | Previews shares received for a deposit         |
| `previewMint()`     | Previews assets required to mint shares        |
| `previewWithdraw()` | Previews shares required for a withdrawal      |
| `previewRedeem()`   | Previews assets received from redeeming shares |
| `totalAssets()`     | Returns the vault's underlying assets          |
| `maxDeposit()`      | Returns the maximum deposit amount             |
| `maxMint()`         | Returns the maximum mint amount                |
| `maxWithdraw()`     | Returns the maximum withdrawable assets        |
| `maxRedeem()`       | Returns the maximum redeemable shares          |

---

# Asset & Share Accounting

The core of ERC-4626 is the relationship between the vault's total assets and total shares.

Conceptually:

### Assets → Shares

```text
shares = assets × totalShares / totalAssets
```

### Shares → Assets

```text
assets = shares × totalAssets / totalShares
```

In practice, integer arithmetic requires careful handling of rounding.

The implementation therefore distinguishes between operations where rounding **down** or **up** is appropriate.

```text
Deposit   → round down
Mint      → round up
Withdraw  → round up
Redeem    → round down
```

Incorrect rounding can result in value leakage between users and the vault.

---

# Inflation / Donation Attack

A significant security consideration in ERC-4626 vaults is the **inflation attack**, also referred to as the **donation attack**.

An ERC-20 token can be transferred directly to the vault without going through the vault's deposit mechanism.

For example:

```text
Initial State

Assets = 1
Shares = 1
```

An attacker can directly donate assets:

```text
Donation

Assets = 101
Shares = 1
```

The vault's asset/share ratio has now changed without any additional shares being issued.

For a subsequent small deposit, integer division and rounding can cause the depositor to receive substantially fewer shares than expected.

This is particularly relevant when a vault has very low initial liquidity.

---

# Mitigation: Virtual Assets & Virtual Shares

This implementation incorporates **virtual assets and virtual shares** into the conversion calculations.

Conceptually:

```text
effectiveAssets = totalAssets + virtualAssets

effectiveShares = totalShares + virtualShares
```

The exchange-rate calculation therefore operates on an adjusted accounting base rather than relying exclusively on the vault's real balances.

```text
                  Real Assets
                       │
                       ▼
              ┌─────────────────┐
              │ + Virtual Assets│
              └─────────────────┘
                       │
                       ▼
                Effective Assets
                       │
                       │
                       ▼
                 Exchange Rate
                       ▲
                       │
                       │
                Effective Shares
                       ▲
              ┌─────────────────┐
              │ + Virtual Shares│
              └─────────────────┘
                       ▲
                       │
                  Real Shares
```

This provides a non-zero virtual baseline and makes manipulating the exchange rate through direct donations substantially more difficult.

### Security objective

The mitigation is designed to reduce the attacker's ability to:

1. Establish a favorable initial share price.
2. Inflate the vault's asset/share ratio through direct donations.
3. Cause a subsequent depositor to receive an unexpectedly small number of shares.
4. Capture value through rounding and share-price manipulation.

---

# Testing

The project uses **Foundry** for comprehensive smart contract testing.

Testing focuses on both normal ERC-4626 behavior and adversarial scenarios.

### Core Tests

* Initial vault state
* Deposits
* Withdrawals
* Minting
* Redeeming
* Asset/share conversions
* Preview functions
* Maximum operation limits
* Rounding behavior

### Security Tests

* Direct asset donations
* Exchange-rate changes after donations
* Small deposits
* Large donations
* Inflation attack scenarios
* Virtual asset/share accounting
* Share dilution
* Edge cases around zero assets and shares

### Property Testing

The project also uses:

* **Fuzz testing**
* **Invariant testing**

These tests help validate accounting properties across a wide range of inputs instead of relying only on fixed examples.

---

# Project Structure

```text
Tokenize-Vault/
│
├── src/
│   └── ERC4626.sol
│
├── test/
│   ├── helper/
│   └── ERC4626UnitTest.t.sol
│
├── lib/
│
├── .github/
│   └── workflows/
│
├── foundry.toml
├── foundry.lock
├── .gitmodules
├── .gitignore
└── README.md
```

---

# Technology Stack

* **Solidity**
* **Foundry**
* **OpenZeppelin Contracts**
* **ERC-20**
* **ERC-4626**
* **Forge**
* **Fuzz Testing**
* **Invariant Testing**

---

# Getting Started

## Prerequisites

Install:

* [Foundry](https://book.getfoundry.sh/)
* Git

## Clone

```bash
git clone https://github.com/abhiblock-96/Tokenize-Vault.git
cd Tokenize-Vault
```

## Install Dependencies

```bash
forge install
```

## Build

```bash
forge build
```

## Run Tests

```bash
forge test
```

## Run Tests With Verbosity

```bash
forge test -vv
```

## Run a Specific Test

```bash
forge test --match-test <testName>
```

---

# Security Considerations

Although this implementation includes protection against the ERC-4626 inflation/donation attack through virtual assets and virtual shares, it should **not** be considered production-ready.

A production vault requires additional consideration for factors such as:

* Rounding edge cases
* Fee mechanisms
* Rebasing assets
* Fee-on-transfer tokens
* Unexpected token donations
* Asset accounting
* Share-price manipulation
* Access control
* Strategy integrations
* External protocol interactions
* Upgradeability, if applicable
* Gas efficiency
* Formal verification and independent auditing

The purpose of this repository is to understand these mechanisms at the implementation level and explore their security implications.

---

# Learning Objectives

This project was built to develop a deeper understanding of:

```text
ERC-4626
   │
   ├── Asset Accounting
   │
   ├── Share Accounting
   │
   ├── Exchange Rates
   │
   ├── Rounding
   │
   ├── Deposits
   │
   ├── Withdrawals
   │
   ├── Minting
   │
   ├── Redeeming
   │
   └── Security
          │
          └── Inflation / Donation Attack
                       │
                       ▼
              Virtual Assets
                       +
              Virtual Shares
                       │
                       ▼
                  Mitigation
```

The primary goal is not simply to implement the ERC-4626 interface, but to understand the **economic and security properties behind the standard**.

---

# References

* [ERC-4626 — Tokenized Vault Standard](https://eips.ethereum.org/EIPS/eip-4626)
* [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
* [Foundry Book](https://book.getfoundry.sh/)

---

# Disclaimer

This repository is provided for **educational and research purposes only**.

The smart contracts have not undergone an independent security audit and should not be deployed with real or production funds.

---

## 👨‍💻 Author

**Abhishek Maurya**

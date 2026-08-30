# ERC-4626 Vault

An educational implementation of the **ERC-4626 Tokenized Vault Standard** written in Solidity.

The purpose of this project is to understand how ERC-4626 vaults work internally, including asset/share accounting, conversion formulas, rounding, deposits, withdrawals, minting, and redeeming.

> ⚠️ **Educational Project — Not Production Ready**
>
> This implementation intentionally focuses on understanding ERC-4626 mechanics and currently contains known security limitations, including vulnerability to **donation/inflation attacks**.
>
> Do **not** use this implementation to manage real funds.

---

## 🎯 Purpose

This project was built to understand ERC-4626 by implementing the core vault functionality rather than simply using an existing implementation.

The vault accepts an underlying ERC-20 asset and issues vault shares representing a user's proportional ownership of the vault's assets.

At a high level:

```text
User
 │
 │ deposit assets
 ▼
┌─────────────────────┐
│     ERC-4626 Vault  │
│                     │
│  Underlying Assets  │
│         ↕           │
│    Vault Shares     │
└─────────────────────┘
 │
 │ shares
 ▼
User
```

---

## 🧠 ERC-4626 Concepts Covered

This implementation explores the main ERC-4626 operations:

| Function            | Purpose                                                  |
| ------------------- | -------------------------------------------------------- |
| `deposit()`         | Deposit assets and receive shares                        |
| `mint()`            | Request a specific number of shares by depositing assets |
| `withdraw()`        | Withdraw a specific amount of assets by burning shares   |
| `redeem()`          | Burn a specific amount of shares to receive assets       |
| `convertToShares()` | Convert assets into shares                               |
| `convertToAssets()` | Convert shares into assets                               |
| `previewDeposit()`  | Preview shares received from a deposit                   |
| `previewMint()`     | Preview assets required to mint shares                   |
| `previewWithdraw()` | Preview shares required for withdrawal                   |
| `previewRedeem()`   | Preview assets received from redeeming shares            |
| `totalAssets()`     | Return assets currently held by the vault                |
| `maxDeposit()`      | Maximum assets that can be deposited                     |
| `maxMint()`         | Maximum shares that can be minted                        |
| `maxWithdraw()`     | Maximum assets an owner can withdraw                     |
| `maxRedeem()`       | Maximum shares an owner can redeem                       |

---

## 📐 Asset / Share Accounting

The core accounting mechanism is based on the relationship between:

```text
totalAssets
      │
      ▼
┌───────────────┐
│     Vault     │
│               │
│ Assets        │
│ Shares        │
└───────────────┘
      │
      ▼
totalSupply
```

The basic conversion formulas are:

### Assets → Shares

```text
shares = assets × totalSupply / totalAssets
```

### Shares → Assets

```text
assets = shares × totalAssets / totalSupply
```

The implementation also uses different rounding directions depending on the operation.

For example:

* Deposits generally round **down**
* Minting generally rounds **up**
* Withdrawals generally round **up**
* Redeeming generally rounds **down**

This is important because incorrect rounding can create value leakage between users and the vault.

---

## 🔐 Initial Vault State

When both:

```text
totalAssets = 0
totalSupply = 0
```

the implementation uses a **1:1 exchange rate**.

Therefore:

```text
1 asset → 1 share
```

for the initial deposit.

This avoids division by zero and establishes the initial share price.

---

# ⚠️ Known Security Issue

## Donation / Inflation Attack

The current implementation is vulnerable to the **ERC-4626 donation/inflation attack**.

The vulnerability comes from the vault determining its exchange rate using its current asset balance:

```text
exchange rate ≈ totalAssets / totalSupply
```

Because `totalAssets()` is based on the underlying token balance held by the vault, assets can potentially be transferred directly to the vault without minting shares.

This changes:

```text
totalAssets
```

without changing:

```text
totalSupply
```

which changes the exchange rate.

### Simplified example

Suppose:

```text
Vault:
1 asset
1 share
```

Exchange rate:

```text
1 asset / 1 share
```

An attacker can donate additional assets directly to the vault.

For example:

```text
10 assets
1 share
```

Now the exchange rate becomes:

```text
10 assets / 1 share
```

A subsequent user's deposit can therefore receive significantly fewer shares than expected.

Depending on the exact amounts and rounding, the attacker can potentially extract value from the victim's deposit.

---

## Why This Matters

This demonstrates an important property of ERC-4626:

> **The underlying asset balance is not necessarily equivalent to assets that were deposited through the vault.**

Direct token transfers can change the vault's accounting state without creating corresponding shares.

This is one of the important security considerations when implementing tokenized vaults.

---

# 🛡️ Mitigation

This repository intentionally keeps the vulnerable implementation available for learning.

Potential approaches for mitigating donation/inflation attacks include techniques such as:

* Virtual assets and virtual shares
* Minimum initial liquidity
* Increased share precision
* Dead shares
* Carefully designed initial deposit mechanisms
* Accounting systems that distinguish managed assets from arbitrary token transfers

The correct mitigation depends on the vault's design and economic model.

The goal of this project is to first understand **why the vulnerability exists** before implementing a mitigation.

---

# 🧪 Security Learning Path

The intended progression for this project is:

```text
ERC-4626 Implementation
        │
        ▼
Understand Share Accounting
        │
        ▼
Understand Rounding
        │
        ▼
Identify Donation Attack
        │
        ▼
Reproduce Attack
        │
        ▼
Design Mitigation
        │
        ▼
Test Mitigation
```

Future versions can therefore demonstrate:

```text
V1 → Basic ERC-4626
V2 → Donation / Inflation Attack
V3 → Mitigation
V4 → Security Tests & Fuzzing
```

---

# 🧰 Tech Stack

* **Solidity**
* **Foundry**
* **OpenZeppelin Contracts**
* **ERC-20**
* **ERC-4626**
* **Foundry Testing**
* **Fuzz Testing**

---

# 📂 Project Goals

The main learning objectives are:

* Understand ERC-4626 architecture
* Implement vault accounting from scratch
* Understand asset/share exchange rates
* Understand rounding direction
* Understand `preview` functions
* Understand the relationship between `totalAssets` and `totalSupply`
* Study donation/inflation attacks
* Practice smart contract security analysis
* Eventually implement and test mitigations

---

# ⚠️ Security Disclaimer

This repository is intended **strictly for educational purposes**.

The implementation has known security limitations and has **not been audited**.

Do not deploy this contract to mainnet or use it to custody real assets.

---

## 📚 What I Learned

This project helped me understand that implementing a tokenized vault is not simply about implementing the ERC-4626 interface.

The difficult part is maintaining correct economic accounting between:

```text
Assets ↔ Shares
```

while handling:

* Rounding
* Initial deposits
* Zero states
* Direct token transfers
* Exchange-rate manipulation
* Share dilution
* Withdrawals and redemptions
* Adversarial users

The donation/inflation attack is particularly important because the Solidity implementation can appear logically correct while the **economic model itself is exploitable**.

---

## 🚀 Future Improvements

* [ ] Add comprehensive Foundry unit tests
* [ ] Add fuzz tests
* [ ] Reproduce donation/inflation attack
* [ ] Add invariant tests
* [ ] Implement mitigation
* [ ] Compare vulnerable vs protected versions
* [ ] Add gas analysis
* [ ] Test against edge cases
* [ ] Compare implementation with OpenZeppelin's ERC-4626 implementation

---

## 👨‍💻 Author

**Abhishek Maurya**


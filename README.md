# 📜 Clarity Lending Protocol Contract

This Clarity smart contract implements a decentralized lending and borrowing protocol on the Stacks blockchain using sBTC. It features:

- Undercollateralized loans based on credit scoring
- Lender deposits with lock durations and share-based withdrawal
- Loan eligibility determined by user on-chain activity and repayment history

---

## 📦 Features

### ✅ Lending
- Lenders deposit sBTC into the pool.
- Funds are locked for a specified duration.
- Withdrawals are proportionate to the lender’s share in the pool.

### 💰 Borrowing
- Undercollateralized loans.
- Credit scores calculated from:
  - Account average balance (past 3 months).
  - On-time vs late repayment history.
- Dynamic loan limits based on score tiers.

### 🔐 Admin Functions
- Set interest rates
- Set lock durations
- Set loan durations

---

## ⚙️ Constants

### Errors
| Name | Description |
|------|-------------|
| `err_not_admin (u100)` | Caller is not the admin |
| `err_input_value_too_small (u101)` | Lend/loan amount is too low |
| `err_not_a_lender (u102)` | Caller is not a lender |
| `err_pool_share_exceeded (u103)` | Withdrawal amount exceeds share |
| `err_not_eligible (u104)` | Not eligible for loan |
| `err_funds_not_available_now (u105)` | Not enough liquidity |
| `err_funds_locked (u106)` | Funds are still locked |
| `err_unable_to_get_block (u107)` | Could not fetch block info |

### Tier Limits
| Tier | Limit |
|------|--------|
| 0 | 10,000 (0.0001 sBTC) |
| 1 | 50,000 (0.0005 sBTC) |
| 2 | 100,000 |
| 3 | 300,000 |
| 4 | 500,000 |
| 5 | 1,000,000 |

---

## 🧠 Credit Scoring System

### Activity Score (based on average balance)
| Balance | Score |
|---------|-------|
| `< tier_0_limit` | 0 |
| `≥ tier_0_limit` | 100 |
| `≥ tier_1_limit` | 220 |
| `≥ tier_2_limit` | 240 |
| `≥ tier_3_limit` | 260 |
| `≥ tier_4_limit` | 280 |
| `≥ tier_5_limit` | 300 |

### Repayment Score
Calculated as:

if total_loans < 5:
score = (on_time_loans * 700) / (total_loans + 5)
else:
score = (on_time_loans * 700) / total_loans

### Loan Limit (based on total credit score)
Total credit score = Activity Score + Repayment Score

| Score Threshold | Max Loan Amount |
|------------------|------------------|
| > 300 | Tier 0 limit |
| > 450 | Tier 1 limit |
| > 600 | Tier 2 limit |
| > 750 | Tier 3 limit |
| > 900 | Tier 4 limit |
| *Else* | Tier 5 limit |

---

## 📤 Public Functions

### `lend(amount)`
- Deposits sBTC into the pool.
- Locks lender’s funds.
- Updates lender info.

### `withdraw(amount)`
- Withdraws funds if unlock block has passed.
- Amount is based on lender’s share of pool.

### `apply-for-loan(amount)`
- Checks eligibility.
- Calculates credit score.
- Disburses loan if eligible.

### `repay-loan(who)`
- Transfers repayment (including interest).
- Updates repayment history.
- Deletes loan record.

---

## 🔍 Read-Only Functions

### `get-withdrawal-limit(lender)`
- Returns max amount lender can withdraw based on pool share and available balance.

---

## 🗺 Data Structures

### `lender_info` (map)
```clojure
principal => {
  balance: uint,
  locked_block: uint,
  unlock_block: uint
}

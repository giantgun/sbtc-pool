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

```clojure
if total_loans < 5:
score = (on_time_loans * 700) / (total_loans + 5)
else:
score = (on_time_loans * 700) / total_loans
```

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


### Public Functions
---

### 💸 Lender Functions

#### `lend (amount uint) -> (response bool)`
Allows a user to lend sBTC to the lending pool. Funds are locked until the specified unlock block.

- **Parameters**: 
  - `amount`: Amount of sBTC to lend (must be ≥ `u10000000`).
- **Emits**: `lend_successful` event.
- **Returns**: `true` if lending is successful.

---

#### `withdraw (amount uint) -> (response bool)`
Allows a lender to withdraw their share of the lending pool after the lock period.

- **Parameters**: 
  - `amount`: Amount to withdraw (must not exceed their pool share and must be unlocked).
- **Emits**: `withdrawal_successful` event.
- **Returns**: `true` if withdrawal is successful.

---

#### `get-withdrawal-limit (lender principal) -> (response {withdrawal_limit: uint})`
Returns the maximum amount the specified lender can currently withdraw.

- **Parameters**: 
  - `lender`: The address of the lender.
- **Returns**: The withdrawal limit for the lender.

---

### 🧾 Borrower Functions

###v `apply-for-loan (amount uint) -> (response bool)`
Allows a borrower to apply for a loan based on their creditworthiness.

- **Parameters**: 
  - `amount`: Amount to borrow.
- **Conditions**:
  - Must be eligible based on average balance and repayment history.
  - Lending pool must have enough funds.
- **Emits**: `loan_grant_successful` event.
- **Returns**: `true` if loan is granted.

---

#### `repay-loan (who principal) -> (response bool)`
Allows a borrower to repay their outstanding loan.

- **Parameters**: 
  - `who`: The borrower’s principal (usually `tx-sender`).
- **Emits**: `loan_repaid_successfully` event.
- **Returns**: `true` if repayment is successful.

---

#### `repayment-amount-due (who principal) -> (response uint)`
Returns the total repayment amount (loan + interest) for a borrower.

- **Parameters**: 
  - `who`: The borrower’s principal.
- **Returns**: Amount due including interest.

---

#### `get-loan-limit-info (who principal) -> (response uint)`
Returns the maximum loan amount available to a borrower based on their credit score.

- **Parameters**: 
  - `who`: The borrower's principal.
- **Returns**: The loan limit the borrower qualifies for.

---

### 🔍 Read-Only Functions

#### `get-loan-eligibility (principal)`
Returns whether the given user is eligible for a loan and the calculated credit score.

**Returns:**  
`(tuple (eligible bool) (score uint) (max-loan uint))`

---

#### `get-loan-limit (score uint)`
Calculates the maximum loan amount based on a given credit score.

**Returns:**  
`uint` — The maximum allowable loan amount.

---

#### `get-activity-score (principal)`
Computes the user's activity score based on their average account balance over the past 3 months.

**Returns:**  
`uint` — Activity score.

---

#### `get-repayment-score (principal)`
Calculates repayment score based on the number of loans and how many were repaid on time.

**Returns:**  
`uint` — Repayment score.

---

#### `get-credit-score (principal)`
Adds up the activity score and repayment score to determine the full credit score.

**Returns:**  
`uint` — Total credit score.

---

#### `get-withdrawal-limit (principal)`
Calculates the maximum amount the user can withdraw from the lending pool based on their locked amount and the current available pool.

**Returns:**  
`uint` — Withdrawable amount.

---

#### `get-lender-info (principal)`
Returns the lender's locked balance and lock period information.

**Returns:**  
`(optional (tuple (balance uint) (locked-block uint) (unlock-block uint)))`

---

#### `get-loan-info (principal)`
Fetches details of the active loan for a user, if any.

**Returns:**  
`(optional (tuple (amount uint) (due-block uint) (interest-rate uint) (issued-block uint)))`

---

#### `get-account-data (principal)`
Returns total loan history for a user.

**Returns:**  
`(optional (tuple (total-loans uint) (on-time-loans uint) (late-loans uint)))`


---

## 📜 Admin Functions

### Admin Verification

#### `(define-private (is-admin) ...)`

- **Description:** Checks whether the `contract-caller` is the current admin.
- **Access:** Private
- **Logic:** Compares `contract-caller` to the current admin stored in `(var-get admin)`. Fails with `err_not_admin` if not equal.

---

### Admin-Controlled Data Variables

The following `define-data-var`s are set and controlled by the admin:

- `admin`: Stores the principal of the current admin (`tx-sender` during deployment).
- `interest_rate_in_percent`: Interest rate used for loan repayments. Default: `u15` (15%).
- `loan_duration_in_days`: Duration of issued loans. Default: `u14` (14 days).
- `lock_duration_in_days`: Lock duration for lender funds. Default: `u0`.

These values are used in borrower eligibility checks, loan issuance, and lender fund lock calculation.

---

### Functions Admin Can Control or Modify

There are no public admin-only functions explicitly named in the contract for modifying the following variables, but based on the structure, any future function that modifies these would require `(is-admin)` checks:

#### 1. `interest_rate_in_percent`
- **Role:** Sets the interest rate on issued loans.
- **Usage:** Used in `(apply-for-loan)` and `(repayment-amount-due)` to calculate total repayment amount.

#### 2. `loan_duration_in_days`
- **Role:** Determines how long a borrower has to repay a loan.
- **Usage:** Used in `(apply-for-loan)` to calculate the loan's due block.

#### 3. `lock_duration_in_days`
- **Role:** Defines how long lender funds are locked before they can be withdrawn.
- **Usage:** Used in `(lend)` and `(withdraw)` to calculate `unlock_block`.

---

## 🧱 Built With

- **Clarity** – Smart contract language for Stacks  
- **sBTC** – Bitcoin-backed asset on Stacks  

## 🧪 Testing

This contract is designed for use on the Stacks testnet/mainnet. Use the **Stacks CLI** and **Clarity REPL** for deployment and testing.

## 👥 Authors

Built by [CulturedBadBoy]. Contributions and feedback welcome!



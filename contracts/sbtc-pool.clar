;; Errors
(define-constant err_not_admin (err u100))
(define-constant err_input_value_too_small  (err u101))
(define-constant err_not_a_lender (err u102))
(define-constant err_pool_share_exceeded (err u103))
(define-constant err_not_eligible (err u104))
(define-constant err_funds_not_available_now (err u105))
(define-constant err_funds_locked (err u106))
(define-constant err_unable_to_get_block (err 107))

;; Tier max
(define-constant tier_0_limit u10000) ;; 0.0001 sbtc
(define-constant tier_1_limit u50000) ;; 0.0005 sBTC
(define-constant tier_2_limit u100000)
(define-constant tier_3_limit u300000)
(define-constant tier_4_limit u500000)
(define-constant tier_5_limit u1000000)
(define-map lender_info principal {balance: uint, locked_block: uint, unlock_block: uint})
(define-data-var total_lending_pool uint u0)

;; Borrower information
(define-data-var admin principal tx-sender)
(define-data-var interest_rate_in_percent uint u15)
(define-data-var loan_duration_in_days uint u14)
(define-data-var lock_duration_in_days uint u30)
(define-map active_loans principal { amount: uint, due_block: uint, interest_rate: uint, issued_block: uint, }) 
(define-map account_data_map principal {
  total_loans: uint,
  on_time_loans: uint,
  late_loans: uint,
  })

(define-private (is-admin)
  (begin
    (asserts! (is-eq contract-caller (var-get admin)) false)
    true
  )
)

;; Determines time per block in seconds
(define-read-only (time-per-block)
  (* u10 u60)
)

;; _____________________Borrower_Helper_Functions_____________________
;; Convert time in days to block
(define-private (convert-days-to-blocks (days uint))
  (/ (* days u24 u60 u60) (time-per-block))
)

;; Calcultate address average balance for the last 3 months
(define-private (get-average-balance (who principal))
  (let (
      (stacks_stacks_id_header_hash_1 (unwrap! (get-stacks-block-info? id-header-hash (- stacks-block-height (convert-days-to-blocks u1))) u0))
      (stacks_stacks_id_header_hash_2 (unwrap! (get-stacks-block-info? id-header-hash (- stacks-block-height (convert-days-to-blocks u31))) u0))
      (stacks_stacks_id_header_hash_3 (unwrap! (get-stacks-block-info? id-header-hash (- stacks-block-height (convert-days-to-blocks u61))) u0))

    )
    (/
      (+ 
        (at-block stacks_stacks_id_header_hash_1 (unwrap! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance who) u0))
        (at-block stacks_stacks_id_header_hash_2 (unwrap! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance who) u0))
        (at-block stacks_stacks_id_header_hash_3 (unwrap! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance who) u0))
      ) 
      u3
    )
  )
)

;; get loan limit based on credit score
(define-private (loan-limit (credit_score uint))
  (begin
    (asserts! (> credit_score u300) tier_0_limit)
    (asserts! (> credit_score u450) tier_1_limit)
    (asserts! (> credit_score u600) tier_2_limit)
    (asserts! (> credit_score u750) tier_3_limit)
    (asserts! (> credit_score u900) tier_4_limit)
    tier_5_limit
  )
)

;; Function to check if debtor pays on time
(define-private (check-for-late-payment-and-update-data-after-payment (who principal))
  (let
    (
      (account_data (default-to 
        { 
          total_loans: u0,
          on_time_loans: u0,
          late_loans: u0,
        }
        (map-get? account_data_map who)
      ))
      (total_loans (get total_loans account_data))
      (on_time_loans (get on_time_loans account_data))
      (late_loans (get late_loans account_data))
      (due_block (default-to u0 (get due_block (map-get? active_loans who))))
      (average_balance (get-average-balance who))
    ) 
    (if (<= stacks-block-height due_block)
      (map-set account_data_map who { ;;
        total_loans: (get total_loans account_data),
        on_time_loans: (+ (get on_time_loans account_data) u1),
        late_loans: (get late_loans account_data),
      })
      (map-set account_data_map who { ;;
        total_loans: (get total_loans account_data),
        on_time_loans: (get on_time_loans account_data),
        late_loans: (+ (get late_loans account_data) u1),
      })
    )
    (map-delete active_loans who)
  )
)

;; Determine activity score based on average balance 
(define-private (activity-score (average_balance uint))
  (begin 
    (asserts! (> average_balance u0) u0)
    (asserts! (>= average_balance tier_0_limit) u100)
    (asserts! (>= average_balance tier_1_limit) u220)
    (asserts! (>= average_balance tier_2_limit) u240)
    (asserts! (>= average_balance tier_3_limit) u260)
    (asserts! (>= average_balance tier_4_limit) u280)
    u300
  )
)

;; Determine repayment score from repayment history
(define-private (repayment-score (total_loans uint) (on_time_loans uint) (late_loans uint))
  (if (> on_time_loans u0)
    (if (< total_loans u5) ;; Makes sure repayment score cannot be 700/700 for new users
      (/ (* on_time_loans u700) (+ total_loans u5)) 
      (/ (* on_time_loans u700) total_loans)
    )
    u0
  )
)

;; Access loan applicant, give a credit score, update data and return true if customer is eligible for loan
(define-private 
  (loan-eligibility 
    (who principal)
    (account_data  {
      total_loans: uint,
      on_time_loans: uint,
      late_loans: uint,
    })
    (amount uint)
  )
  (let 
    (
      (total_loans (get total_loans account_data))
      (on_time_loans (get on_time_loans account_data))
      (late_loans (get late_loans account_data))
      (average_balance (get-average-balance who))
    )
    (if (is-eq total_loans u0)
      (begin
        (asserts! (is-eq (+ late_loans on_time_loans) total_loans) false) ;; Make sure they are no pending loan payments
        (asserts! (>= average_balance amount) false)
        (asserts! (>= (loan-limit (+ (activity-score average_balance) (repayment-score total_loans on_time_loans late_loans))) amount) false)
        (map-set account_data_map who { 
            total_loans: total_loans,
            on_time_loans: on_time_loans,
            late_loans: late_loans,
          }
        )
        true
      )
      (begin 
        (asserts! (is-eq (+ late_loans on_time_loans) total_loans) false) ;; Make sure they are no pending loan payments
        (asserts! (>= average_balance amount) false)
        (asserts! (>= (loan-limit (+ (repayment-score total_loans on_time_loans late_loans) (activity-score average_balance))) amount) false)
        (map-set account_data_map who {
            total_loans: total_loans,
            on_time_loans: on_time_loans,
            late_loans: late_loans,
          }
        )
        true
      )
    )
  ) 
)

;; _____________________Lender_Functions_____________________
(define-public (lend (amount uint))
  (let
    (
      (lender_balance (default-to u0 (get balance (map-get? lender_info tx-sender))))
    ) 
    (asserts! (>= amount u10000000) err_input_value_too_small)
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token transfer amount tx-sender (as-contract tx-sender) none))
    (map-set lender_info tx-sender 
      {
        balance: (+ lender_balance amount), 
        locked_block: stacks-block-height, 
        unlock_block: (+ stacks-block-height (convert-days-to-blocks (var-get lock_duration_in_days)))
      }
    )
    (var-set total_lending_pool (+ (var-get total_lending_pool) amount))
    (print {
      event: "lend_sucessful",
      user: tx-sender,
      amount: amount, 
      locked_block: (default-to u0 (get locked_block (map-get? lender_info tx-sender))),
      unlock_block: (default-to u0 (get unlock_block (map-get? lender_info tx-sender)))
    })
    (ok true)
  )
)

(define-public (withdraw (amount uint)) 
  (begin
    (let
      (
        (lender_balance (default-to u0 (get balance (map-get? lender_info tx-sender))))
        (unlock_block (default-to u0 (get unlock_block (map-get? lender_info tx-sender))))
        (locked_block (default-to u0 (get locked_block (map-get? lender_info tx-sender))))
        (contract_balance (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender))))
        (lender_pool_balance 
          (if (> lender_balance u0)
            (/ (* lender_balance contract_balance) (var-get total_lending_pool))
            u0
          )
        ) ;; calculate the lenders' percentage of the pool
      )
      (asserts! (> lender_balance u0) err_not_a_lender)
      (asserts! (<= amount lender_pool_balance) err_pool_share_exceeded)
      (asserts! (<= unlock_block stacks-block-height) err_funds_locked)
      (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token transfer amount (as-contract tx-sender) tx-sender none))
      (var-set total_lending_pool 
        (if (< lender_balance amount)
          (+ 
            (- (var-get total_lending_pool) lender_balance)
            (- lender_pool_balance amount)
          )
          (- (var-get total_lending_pool) amount)
        )
      )
      (if (>= amount lender_balance)
        (if (is-eq amount lender_pool_balance)
          (map-delete lender_info tx-sender)
          (map-set lender_info tx-sender 
            {
              balance: (- lender_pool_balance amount),
              locked_block: locked_block,
              unlock_block: unlock_block
            }
          )
        )
        (if (< lender_balance lender_pool_balance)
          (map-set lender_info tx-sender 
            {
              balance: (- lender_pool_balance amount),
              locked_block: locked_block,
              unlock_block: unlock_block
            }
          )
          (map-set lender_info tx-sender 
            {
              balance: (- lender_balance amount),
              locked_block: locked_block,
              unlock_block: unlock_block
            }
          )
        )
      )
    )
    (print {event: "withdrawal_sucessful", user: tx-sender, amount: amount, data: (default-to u0 (get unlock_block (map-get? lender_info tx-sender)))})
    (ok true)
  )
)

;; ____________Lender_read-only_functions____________
(define-read-only (get-withdrawal-limit (lender principal))
  (let
    (
      (lender_balance (default-to u0 (get balance (map-get? lender_info tx-sender))))
      (contract_balance (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender))))
      (lender_pool_balance 
        (if (> lender_balance u0)
          (/ (* lender_balance contract_balance) (var-get total_lending_pool))
          u0
        )
      )
    )
    (asserts! (> lender_balance u0) err_not_a_lender)
    (print {withdrawal_limit: lender_pool_balance})
    (ok {withdrawal_limit: lender_pool_balance})
  )
)

;; _____________________Borrower_Functions_____________________
(define-public (apply-for-loan (amount uint)) 
  (let 
    (
      (account_data (default-to {
          total_loans: u0,
          on_time_loans: u0,
          late_loans: u0,
        } (map-get? account_data_map tx-sender)
      ))
      (loan_duration_in_blocks (convert-days-to-blocks (var-get loan_duration_in_days)))
    )
    (asserts! (> amount u0) err_input_value_too_small)
    (asserts! (loan-eligibility tx-sender account_data amount) err_not_eligible)
    (asserts! (> (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender))) amount) err_funds_not_available_now)
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token transfer amount (as-contract tx-sender) tx-sender none))
    (map-set active_loans tx-sender {
      amount: amount,
      due_block: (+ stacks-block-height loan_duration_in_blocks),
      interest_rate: (var-get interest_rate_in_percent),
      issued_block: stacks-block-height
    })
    (map-set account_data_map tx-sender {
      total_loans: (+ u1 (get total_loans account_data)),
      on_time_loans: (get on_time_loans account_data),
      late_loans: (get late_loans account_data),
    })
    (print 
      {
        event: "loan_grant_sucessful", 
        user: tx-sender, 
        amount_to_repay: (repayment_amount_due tx-sender), 
        amount: amount, 
        due_block: (+ stacks-block-height loan_duration_in_blocks), 
        interest_rate: (var-get interest_rate_in_percent), 
        issued_block: stacks-block-height
      })
    (ok true)
  )
)

(define-public (repay-loan (who principal))
  (let 
    (
      (loan_data (default-to { amount: u0, due_block: u0, interest_rate: u0, issued_block: u0, } (map-get? active_loans who)))
      (amount (get amount loan_data))
      (due_block (get due_block loan_data))
      (interest_rate (get interest_rate loan_data))
      (issued_block (get issued_block loan_data))
      (repayment_amount (repayment_amount_due who))
    )
    (asserts! (> (get amount loan_data) u0) err_not_eligible)
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token transfer repayment_amount tx-sender (as-contract tx-sender) none))
    (check-for-late-payment-and-update-data-after-payment who)
    (print {event: "loan_repaid_sucessfully", user: tx-sender, amount: repayment_amount})
    (ok true)
  )
)

;; ____________Borrower_read-only_functions____________
;; Calculate amount due for repayment
(define-read-only (repayment-amount-due (who principal))
  (let 
    (
      (amount (default-to u0 (get amount (map-get? active_loans who))))
      (interest_rate (default-to u0 (get interest_rate (map-get? active_loans who))))
    )
    (if (> interest_rate u0)
      (+ amount (/ (* amount interest_rate) u100))
      u0
    )
  )
)

(define-read-only (get-loan-limit-info (who principal))
  (let
    (
      (account_data (default-to {
          total_loans: u0,
          on_time_loans: u0,
          late_loans: u0,
        } (map-get? account_data_map tx-sender)
      ))
      (total_loans (get total_loans account_data))
      (on_time_loans (get on_time_loans account_data))
      (late_loans (get late_loans account_data))
      (average_balance (get-average-balance who))
      (credit_score_limit (loan-limit (+ (repayment-score total_loans on_time_loans late_loans) (activity-score average_balance))))
    )
    (asserts! (is-eq total_loans (+ late_loans on_time_loans)) (ok {
      credit_score: (+ (repayment-score total_loans on_time_loans late_loans) (activity-score average_balance)),
      credit_score_limit: credit_score_limit,
      average_balance: average_balance,
      loan-limit: u0
    }))
    (asserts! (< average_balance credit_score_limit) (ok {
      credit_score: (+ (repayment-score total_loans on_time_loans late_loans) (activity-score average_balance)),
      credit_score_limit: credit_score_limit,
      average_balance: average_balance,
      loan-limit: credit_score_limit
    }))
    (ok {
      credit_score: (+ (repayment-score total_loans on_time_loans late_loans) (activity-score average_balance)),
      credit_score_limit: credit_score_limit,
      average_balance: average_balance,
      loan-limit: average_balance
    })
  )
)

;; _____________________Admin_Functions_____________________
(define-public (set-admin (who principal))
  (begin  
    (asserts! (is-admin) err_not_admin)
    (ok (var-set admin who))
  )
)

(define-public (set-loan-duration-in-days (duration uint))
  (begin
    (asserts! (is-admin) err_not_admin)
    (asserts! (>= duration u7) err_input_value_too_small)
    (ok (var-set loan_duration_in_days duration))
  )
)

(define-public (set-lock-duration-in-days (duration uint))
  (begin
    (asserts! (is-admin) err_not_admin)
    (asserts! (> duration u0) err_input_value_too_small)
    (ok (var-set lock_duration_in_days duration))
  )
)

(define-public (set-interest-rate-in-percent (duration uint))
  (begin
    (asserts! (is-admin) err_not_admin)
    (asserts! (> duration u0) err_input_value_too_small)
    (ok (var-set lock_duration_in_days duration))
  )
)

;; _____________________Auxilliariy_read-only_Functions_____________________

(define-read-only (get-loan-eligibility-info (who principal))
  (let
    (
      (account_data (default-to 
        { 
          total_loans: u0,
          on_time_loans: u0,
          late_loans: u0,
        }
        (map-get? account_data_map who)
      ))
      (total_loans (get total_loans account_data))
      (on_time_loans (get on_time_loans account_data))
      (late_loans (get late_loans account_data))
      (average_balance (get-average-balance who))
      (credit_score_limit (loan-limit (+ (repayment-score total_loans on_time_loans late_loans) (activity-score average_balance))))
    )
    (if (> total_loans (+ on_time_loans late_loans))
      (ok {
        message: "address has an unpaid loan",
        loan-limit: u0,
        interest_rate: (var-get interest_rate_in_percent)
      })
      (if (>= credit_score_limit average_balance)
        (ok {
          message: "eligible for loan",
          loan-limit: average_balance,
          interest_rate: (var-get interest_rate_in_percent)
        })
        (ok {
          message: "eligible for loan",
          loan-limit: credit_score_limit,
          interest_rate: (var-get interest_rate_in_percent)
        })
      )
    )
  )
)

(define-read-only (get-lending-pool-info)
  (ok {
    pool_size: (var-get total_lending_pool),
    contract_balance: (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender)))
  })
)

(define-read-only (get-lender-info)
  (let
    (
      (lender_balance (default-to u0 (get balance (map-get? lender_info tx-sender))))
      (contract_balance (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender))))
      (locked_block (default-to u0 (get locked_block (map-get? lender_info tx-sender))))
      (unlock_block (default-to u0 (get unlock_block (map-get? lender_info tx-sender))))
    )
    (ok {
      lender_balance: lender_balance,
      lender_pool_balance:  
        (if (> lender_balance u0)
          (/ (* lender_balance contract_balance) (var-get total_lending_pool))
          u0
        ),
      locked_block: locked_block,
      unlock_block: unlock_block,
      time_in_pool_in_seconds:  (/ (- stacks-block-height locked_block) (time-per-block)),
    })
  )
)

(define-read-only (get-borrower-info (who principal))
  (ok {
    active_loan: (map-get? active_loans who),
    account_data: (map-get? account_data_map who)
  })
)
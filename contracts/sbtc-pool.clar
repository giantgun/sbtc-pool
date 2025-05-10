;; Errors
(define-constant err-not-admin (err u100))
(define-constant err-input-value-too-small  (err u101))
(define-constant err-not-a-lender (err u102))
(define-constant err-pool-share-exceeded (err u103))
(define-constant err-not-eligible (err u104))
(define-constant err-funds-not-available-now (err u105))
(define-constant err-funds-locked (err u106))
(define-constant err-unable-to-get-block (err 107))

;; Tier max
(define-constant tier-0-limit u10000) ;; 0.0001 sbtc
(define-constant tier-1-limit u50000) ;; 0.0005 sBTC
(define-constant tier-2-limit u100000)
(define-constant tier-3-limit u300000)
(define-constant tier-4-limit u500000)
(define-constant tier-5-limit u1000000)
(define-map lender-info principal {balance: uint, locked-block: uint, unlock-block: uint})
(define-data-var total-lending-pool uint u0)

;; Borrower information
(define-data-var admin principal tx-sender)
(define-data-var interest-rate-in-percent uint u15)
(define-data-var loan-duration-in-days uint u14)
(define-data-var lock-duration-in-days uint u30)
(define-map active-loans principal { amount: uint, due-block: uint, interest-rate: uint, issued-block: uint, }) 
(define-map account-data-map principal {
  total-loans: uint,
  on-time-loans: uint,
  late-loans: uint,
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

;; ---------------------Borrower-Helper-Functions---------------------
;; Convert time in days to block
(define-private (convert-days-to-blocks (days uint))
  (/ (* days u24 u60 u60) (time-per-block))
)

;; Calcultate address average balance for the last 3 months
(define-private (get-average-balance (who principal))
  (let (
      (stacks-id-header-hash-1 (unwrap! (get-stacks-block-info? id-header-hash (- stacks-block-height (convert-days-to-blocks u1))) u0))
      (stacks-id-header-hash-2 (unwrap! (get-stacks-block-info? id-header-hash (- stacks-block-height (convert-days-to-blocks u31))) u0))
      (stacks-id-header-hash-3 (unwrap! (get-stacks-block-info? id-header-hash (- stacks-block-height (convert-days-to-blocks u61))) u0))

    )
    (/
      (+ 
        (at-block stacks-id-header-hash-1 (unwrap! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance who) u0))
        (at-block stacks-id-header-hash-2 (unwrap! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance who) u0))
        (at-block stacks-id-header-hash-3 (unwrap! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance who) u0))
      ) 
      u3
    )
  )
)

;; get loan limit based on credit score
(define-private (loan-limit (credit-score uint))
  (begin
    (asserts! (> credit-score u300) tier-0-limit)
    (asserts! (> credit-score u450) tier-1-limit)
    (asserts! (> credit-score u600) tier-2-limit)
    (asserts! (> credit-score u750) tier-3-limit)
    (asserts! (> credit-score u900) tier-4-limit)
    tier-5-limit
  )
)

;; Function to check if debtor pays on time
(define-private (check-for-late-payment-and-update-data-after-payment (who principal))
  (let
    (
      (account-data (default-to 
        { 
          total-loans: u0,
          on-time-loans: u0,
          late-loans: u0,
        }
        (map-get? account-data-map who)
      ))
      (total-loans (get total-loans account-data))
      (on-time-loans (get on-time-loans account-data))
      (late-loans (get late-loans account-data))
      (due-block (default-to u0 (get due-block (map-get? active-loans who))))
      (average-balance (get-average-balance who))
    ) 
    (if (<= stacks-block-height due-block)
      (map-set account-data-map who { ;;
        total-loans: (get total-loans account-data),
        on-time-loans: (+ (get on-time-loans account-data) u1),
        late-loans: (get late-loans account-data),
      })
      (map-set account-data-map who { ;;
        total-loans: (get total-loans account-data),
        on-time-loans: (get on-time-loans account-data),
        late-loans: (+ (get late-loans account-data) u1),
      })
    )
    (map-delete active-loans who)
  )
)

;; Determine activity score based on average balance 
(define-private (activity-score (average-balance uint))
  (begin 
    (asserts! (> average-balance u0) u0)
    (asserts! (>= average-balance tier-0-limit) u100)
    (asserts! (>= average-balance tier-1-limit) u220)
    (asserts! (>= average-balance tier-2-limit) u240)
    (asserts! (>= average-balance tier-3-limit) u260)
    (asserts! (>= average-balance tier-4-limit) u280)
    u300
  )
)

;; Determine repayment score from repayment history
(define-private (repayment-score (total-loans uint) (on-time-loans uint) (late-loans uint))
  (if (> on-time-loans u0)
    (if (< total-loans u5) ;; Makes sure repayment score cannot be 700/700 for new users
      (/ (* on-time-loans u700) (+ total-loans u5)) 
      (/ (* on-time-loans u700) total-loans)
    )
    u0
  )
)

;; Access loan applicant, give a credit score, update data and return true if customer is eligible for loan
(define-private 
  (loan-eligibility 
    (who principal)
    (account-data  {
      total-loans: uint,
      on-time-loans: uint,
      late-loans: uint,
    })
    (amount uint)
  )
  (let 
    (
      (total-loans (get total-loans account-data))
      (on-time-loans (get on-time-loans account-data))
      (late-loans (get late-loans account-data))
      (average-balance (get-average-balance who))
    )
    (if (is-eq total-loans u0)
      (begin
        (asserts! (is-eq (+ late-loans on-time-loans) total-loans) false) ;; Make sure they are no pending loan payments
        (asserts! (>= average-balance amount) false)
        (asserts! (>= (loan-limit (+ (activity-score average-balance) (repayment-score total-loans on-time-loans late-loans))) amount) false)
        (map-set account-data-map who { 
            total-loans: total-loans,
            on-time-loans: on-time-loans,
            late-loans: late-loans,
          }
        )
        true
      )
      (begin 
        (asserts! (is-eq (+ late-loans on-time-loans) total-loans) false) ;; Make sure they are no pending loan payments
        (asserts! (>= average-balance amount) false)
        (asserts! (>= (loan-limit (+ (repayment-score total-loans on-time-loans late-loans) (activity-score average-balance))) amount) false)
        (map-set account-data-map who {
            total-loans: total-loans,
            on-time-loans: on-time-loans,
            late-loans: late-loans,
          }
        )
        true
      )
    )
  ) 
)

;; ---------------------Lender-Functions---------------------
(define-public (lend (amount uint))
  (let
    (
      (lender-balance (default-to u0 (get balance (map-get? lender-info tx-sender))))
    ) 
    (asserts! (>= amount u10000000) err-input-value-too-small)
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token transfer amount tx-sender (as-contract tx-sender) none))
    (map-set lender-info tx-sender 
      {
        balance: (+ lender-balance amount), 
        locked-block: stacks-block-height, 
        unlock-block: (+ stacks-block-height (convert-days-to-blocks (var-get lock-duration-in-days)))
      }
    )
    (var-set total-lending-pool (+ (var-get total-lending-pool) amount))
    (print {
      event: "lend-sucessful",
      user: tx-sender,
      amount: amount, 
      locked-block: (default-to u0 (get locked-block (map-get? lender-info tx-sender))),
      unlock-block: (default-to u0 (get unlock-block (map-get? lender-info tx-sender)))
    })
    (ok true)
  )
)

(define-public (withdraw (amount uint)) 
  (begin
    (let
      (
        (lender-balance (default-to u0 (get balance (map-get? lender-info tx-sender))))
        (unlock-block (default-to u0 (get unlock-block (map-get? lender-info tx-sender))))
        (locked-block (default-to u0 (get locked-block (map-get? lender-info tx-sender))))
        (contract-balance (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender))))
        (lender-pool-balance 
          (if (> lender-balance u0)
            (/ (* lender-balance contract-balance) (var-get total-lending-pool))
            u0
          )
        ) ;; calculate the lenders' percentage of the pool
      )
      (asserts! (> lender-balance u0) err-not-a-lender)
      (asserts! (<= amount lender-pool-balance) err-pool-share-exceeded)
      (asserts! (<= unlock-block stacks-block-height) err-funds-locked)
      (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token transfer amount (as-contract tx-sender) tx-sender none))
      (var-set total-lending-pool 
        (if (< lender-balance amount)
          (+ 
            (- (var-get total-lending-pool) lender-balance)
            (- lender-pool-balance amount)
          )
          (- (var-get total-lending-pool) amount)
        )
      )
      (if (>= amount lender-balance)
        (if (is-eq amount lender-pool-balance)
          (map-delete lender-info tx-sender)
          (map-set lender-info tx-sender 
            {
              balance: (- lender-pool-balance amount),
              locked-block: locked-block,
              unlock-block: unlock-block
            }
          )
        )
        (if (< lender-balance lender-pool-balance)
          (map-set lender-info tx-sender 
            {
              balance: (- lender-pool-balance amount),
              locked-block: locked-block,
              unlock-block: unlock-block
            }
          )
          (map-set lender-info tx-sender 
            {
              balance: (- lender-balance amount),
              locked-block: locked-block,
              unlock-block: unlock-block
            }
          )
        )
      )
    )
    (print {event: "withdrawal-sucessful", user: tx-sender, amount: amount, data: (default-to u0 (get unlock-block (map-get? lender-info tx-sender)))})
    (ok true)
  )
)

;; ------------Lender-read-only-functions------------
(define-read-only (get-withdrawal-limit (lender principal))
  (let
    (
      (lender-balance (default-to u0 (get balance (map-get? lender-info tx-sender))))
      (contract-balance (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender))))
      (lender-pool-balance 
        (if (> lender-balance u0)
          (/ (* lender-balance contract-balance) (var-get total-lending-pool))
          u0
        )
      )
    )
    (asserts! (> lender-balance u0) err-not-a-lender)
    (print {withdrawal-limit: lender-pool-balance})
    (ok {withdrawal-limit: lender-pool-balance})
  )
)

;; ---------------------Borrower-Functions---------------------
(define-public (apply-for-loan (amount uint)) 
  (let 
    (
      (account-data (default-to {
          total-loans: u0,
          on-time-loans: u0,
          late-loans: u0,
        } (map-get? account-data-map tx-sender)
      ))
      (loan-duration-in-blocks (convert-days-to-blocks (var-get loan-duration-in-days)))
    )
    (asserts! (> amount u0) err-input-value-too-small)
    (asserts! (loan-eligibility tx-sender account-data amount) err-not-eligible)
    (asserts! (> (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender))) amount) err-funds-not-available-now)
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token transfer amount (as-contract tx-sender) tx-sender none))
    (map-set active-loans tx-sender {
      amount: amount,
      due-block: (+ stacks-block-height loan-duration-in-blocks),
      interest-rate: (var-get interest-rate-in-percent),
      issued-block: stacks-block-height
    })
    (map-set account-data-map tx-sender {
      total-loans: (+ u1 (get total-loans account-data)),
      on-time-loans: (get on-time-loans account-data),
      late-loans: (get late-loans account-data),
    })
    (print 
      {
        event: "loan-grant-sucessful", 
        user: tx-sender, 
        amount-to-repay: (repayment-amount-due tx-sender), 
        amount: amount, 
        due-block: (+ stacks-block-height loan-duration-in-blocks), 
        interest-rate: (var-get interest-rate-in-percent), 
        issued-block: stacks-block-height
      })
    (ok true)
  )
)

(define-public (repay-loan (who principal))
  (let 
    (
      (loan-data (default-to { amount: u0, due-block: u0, interest-rate: u0, issued-block: u0, } (map-get? active-loans who)))
      (amount (get amount loan-data))
      (due-block (get due-block loan-data))
      (interest-rate (get interest-rate loan-data))
      (issued-block (get issued-block loan-data))
      (repayment-amount (repayment-amount-due who))
    )
    (asserts! (> (get amount loan-data) u0) err-not-eligible)
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token transfer repayment-amount tx-sender (as-contract tx-sender) none))
    (check-for-late-payment-and-update-data-after-payment who)
    (print {event: "loan-repaid-sucessfully", user: tx-sender, amount: repayment-amount})
    (ok true)
  )
)

;; ------------Borrower-read-only-functions------------
;; Calculate amount due for repayment
(define-read-only (repayment-amount-due (who principal))
  (let 
    (
      (amount (default-to u0 (get amount (map-get? active-loans who))))
      (interest-rate (default-to u0 (get interest-rate (map-get? active-loans who))))
    )
    (if (> interest-rate u0)
      (+ amount (/ (* amount interest-rate) u100))
      u0
    )
  )
)

(define-read-only (get-loan-limit-info (who principal))
  (let
    (
      (account-data (default-to {
          total-loans: u0,
          on-time-loans: u0,
          late-loans: u0,
        } (map-get? account-data-map tx-sender)
      ))
      (total-loans (get total-loans account-data))
      (on-time-loans (get on-time-loans account-data))
      (late-loans (get late-loans account-data))
      (average-balance (get-average-balance who))
      (credit-score-limit (loan-limit (+ (repayment-score total-loans on-time-loans late-loans) (activity-score average-balance))))
    )
    (asserts! (is-eq total-loans (+ late-loans on-time-loans)) {
      credit-score: (+ (repayment-score total-loans on-time-loans late-loans) (activity-score average-balance)),
      credit-score-limit: credit-score-limit,
      average-balance: average-balance,
      loan-limit: u0
    })
    (asserts! (< average-balance credit-score-limit) {
      credit-score: (+ (repayment-score total-loans on-time-loans late-loans) (activity-score average-balance)),
      credit-score-limit: credit-score-limit,
      average-balance: average-balance,
      loan-limit: credit-score-limit
    })
    {
      credit-score: (+ (repayment-score total-loans on-time-loans late-loans) (activity-score average-balance)),
      credit-score-limit: credit-score-limit,
      average-balance: average-balance,
      loan-limit: average-balance
    }
  )
)

;; ---------------------Admin-Functions---------------------
(define-public (set-admin (who principal))
  (begin  
    (asserts! (is-admin) err-not-admin)
    (ok (var-set admin who))
  )
)

(define-public (set-loan-duration-in-days (duration uint))
  (begin
    (asserts! (is-admin) err-not-admin)
    (asserts! (>= duration u7) err-input-value-too-small)
    (ok (var-set loan-duration-in-days duration))
  )
)

(define-public (set-lock-duration-in-days (duration uint))
  (begin
    (asserts! (is-admin) err-not-admin)
    (asserts! (> duration u0) err-input-value-too-small)
    (ok (var-set lock-duration-in-days duration))
  )
)

(define-public (set-interest-rate-in-percent (duration uint))
  (begin
    (asserts! (is-admin) err-not-admin)
    (asserts! (> duration u0) err-input-value-too-small)
    (ok (var-set lock-duration-in-days duration))
  )
)

;; ---------------------Auxilliariy-Read-Only-Functions---------------------

(define-read-only (get-loan-eligibility-info (who principal))
  (let
    (
      (account-data (default-to 
        { 
          total-loans: u0,
          on-time-loans: u0,
          late-loans: u0,
        }
        (map-get? account-data-map who)
      ))
      (total-loans (get total-loans account-data))
      (on-time-loans (get on-time-loans account-data))
      (late-loans (get late-loans account-data))
      (average-balance (get-average-balance who))
      (credit-score-limit (loan-limit (+ (repayment-score total-loans on-time-loans late-loans) (activity-score average-balance))))
    )
    (if (> total-loans (+ on-time-loans late-loans))
      (ok {
        message: "address has an unpaid loan",
        loan-limit: u0,
        interest-rate: (var-get interest-rate-in-percent)
      })
      (if (>= credit-score-limit average-balance)
        (ok {
          message: "eligible for loan",
          loan-limit: average-balance,
          interest-rate: (var-get interest-rate-in-percent)
        })
        (ok {
          message: "eligible for loan",
          loan-limit: credit-score-limit,
          interest-rate: (var-get interest-rate-in-percent)
        })
      )
    )
  )
)

(define-read-only (get-lending-pool-info)
  (ok {
    pool-size: (var-get total-lending-pool),
    contract-balance: (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender)))
  })
)

(define-read-only (get-lender-info)
  (let
    (
      (lender-balance (default-to u0 (get balance (map-get? lender-info tx-sender))))
      (contract-balance (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender))))
      (locked-block (default-to u0 (get locked-block (map-get? lender-info tx-sender))))
      (unlock-block (default-to u0 (get unlock-block (map-get? lender-info tx-sender))))
    )
    (ok {
      lender-balance: lender-balance,
      lender-pool-balance:  
        (if (> lender-balance u0)
          (/ (* lender-balance contract-balance) (var-get total-lending-pool))
          u0
        ),
      locked-block: locked-block,
      unlock-block: unlock-block,
      time-in-pool-in-seconds:  (/ (- stacks-block-height locked-block) (time-per-block)),
    })
  )
)

(define-read-only (get-borrower-info (who principal))
  (ok {
    active-loan: (map-get? active-loans who),
    account-data: (map-get? account-data-map who)
  })
)
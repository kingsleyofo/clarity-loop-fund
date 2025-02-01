;; LoopFund - Microlending Platform Contract

;; Constants
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-FUNDED (err u401))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-UNAUTHORIZED (err u403))
(define-constant ERR-LOAN-NOT-ACTIVE (err u405))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u406))
(define-constant ERR-INVALID-SCORE (err u407))

;; Data Variables
(define-data-var next-loan-id uint u0)

;; Define loan status values
(define-constant LOAN-STATUS-REQUESTED u0)
(define-constant LOAN-STATUS-FUNDED u1)
(define-constant LOAN-STATUS-REPAID u2)
(define-constant LOAN-STATUS-DEFAULTED u3)
(define-constant LOAN-STATUS-LIQUIDATED u4)

;; Data Maps
(define-map Loans 
    uint 
    {
        borrower: principal,
        amount: uint,
        interest-rate: uint,
        term-length: uint,
        status: uint,
        lender: (optional principal),
        created-at: uint,
        funded-at: (optional uint),
        repaid-amount: uint,
        collateral-amount: uint,
        credit-score: uint
    }
)

(define-map UserScores
    principal
    {
        score: uint,
        loans-completed: uint,
        loans-defaulted: uint
    }
)

(define-map UserLoans
    principal
    (list 10 uint)
)

;; Private Functions
(define-private (get-next-loan-id)
    (let ((current-id (var-get next-loan-id)))
        (var-set next-loan-id (+ current-id u1))
        current-id
    )
)

(define-private (calculate-credit-score (user principal))
    (match (map-get? UserScores user)
        score-data (ok (get score score-data))
        (ok u500) ;; Default starting score
    )
)

(define-private (update-credit-score (user principal) (success bool))
    (let ((current-data (default-to 
        { score: u500, loans-completed: u0, loans-defaulted: u0 }
        (map-get? UserScores user)
        )))
        (if success
            (map-set UserScores user
                (merge current-data {
                    score: (min (+ (get score current-data) u50) u1000),
                    loans-completed: (+ (get loans-completed current-data) u1)
                }))
            (map-set UserScores user
                (merge current-data {
                    score: (max (- (get score current-data) u100) u0),
                    loans-defaulted: (+ (get loans-defaulted current-data) u1)
                }))
        )
    )
)

;; Public Functions
(define-public (create-loan-request (amount uint) (interest-rate uint) (term-length uint) (collateral uint))
    (let (
        (loan-id (get-next-loan-id))
        (user-score (unwrap! (calculate-credit-score tx-sender) ERR-INVALID-SCORE))
    )
        (asserts! (>= (* collateral u100) (* amount u50)) ERR-INSUFFICIENT-COLLATERAL)
        (try! (stx-transfer? collateral tx-sender (as-contract tx-sender)))
        
        (map-set Loans
            loan-id
            {
                borrower: tx-sender,
                amount: amount,
                interest-rate: interest-rate,
                term-length: term-length,
                status: LOAN-STATUS-REQUESTED,
                lender: none,
                created-at: block-height,
                funded-at: none,
                repaid-amount: u0,
                collateral-amount: collateral,
                credit-score: user-score
            }
        )
        (ok loan-id)
    )
)

(define-public (fund-loan (loan-id uint))
    (let (
        (loan (unwrap! (map-get? Loans loan-id) ERR-NOT-FOUND))
        (amount (get amount loan))
    )
        (asserts! (is-eq (get status loan) LOAN-STATUS-REQUESTED) ERR-ALREADY-FUNDED)
        (try! (stx-transfer? amount tx-sender (get borrower loan)))
        (map-set Loans
            loan-id
            (merge loan {
                status: LOAN-STATUS-FUNDED,
                lender: (some tx-sender),
                funded-at: (some block-height)
            })
        )
        (ok true)
    )
)

(define-public (repay-loan (loan-id uint) (payment uint))
    (let (
        (loan (unwrap! (map-get? Loans loan-id) ERR-NOT-FOUND))
        (lender (unwrap! (get lender loan) ERR-LOAN-NOT-ACTIVE))
    )
        (asserts! (is-eq (get status loan) LOAN-STATUS-FUNDED) ERR-LOAN-NOT-ACTIVE)
        (asserts! (is-eq tx-sender (get borrower loan)) ERR-UNAUTHORIZED)
        (try! (stx-transfer? payment tx-sender lender))
        
        (let ((new-status (if (>= (+ (get repaid-amount loan) payment) 
                                (+ (get amount loan) 
                                   (/ (* (get amount loan) (get interest-rate loan)) u100)))
                            LOAN-STATUS-REPAID
                            LOAN-STATUS-FUNDED)))
            
            (map-set Loans loan-id
                (merge loan {
                    repaid-amount: (+ (get repaid-amount loan) payment),
                    status: new-status
                })
            )
            
            (when (is-eq new-status LOAN-STATUS-REPAID)
                (try! (as-contract (stx-transfer? (get collateral-amount loan) 
                                                tx-sender 
                                                (get borrower loan))))
                (update-credit-score (get borrower loan) true)
            )
            
            (ok true)
        )
    )
)

(define-public (liquidate-defaulted-loan (loan-id uint))
    (let (
        (loan (unwrap! (map-get? Loans loan-id) ERR-NOT-FOUND))
        (lender (unwrap! (get lender loan) ERR-LOAN-NOT-ACTIVE))
    )
        (asserts! (is-eq (get status loan) LOAN-STATUS-FUNDED) ERR-LOAN-NOT-ACTIVE)
        (asserts! (> (- block-height (unwrap! (get funded-at loan) ERR-NOT-FOUND)) 
                   (get term-length loan)) ERR-UNAUTHORIZED)
        
        (try! (as-contract (stx-transfer? (get collateral-amount loan) 
                                        tx-sender 
                                        lender)))
        
        (map-set Loans loan-id
            (merge loan {
                status: LOAN-STATUS-LIQUIDATED
            })
        )
        
        (update-credit-score (get borrower loan) false)
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-loan (loan-id uint))
    (map-get? Loans loan-id)
)

(define-read-only (get-user-credit-score (user principal))
    (map-get? UserScores user)
)

(define-read-only (get-loan-full-repayment-amount (loan-id uint))
    (match (map-get? Loans loan-id)
        loan (ok (+ (get amount loan) 
                   (/ (* (get amount loan) (get interest-rate loan)) u100)))
        ERR-NOT-FOUND
    )
)

(define-read-only (get-loan-remaining-amount (loan-id uint))
    (match (map-get? Loans loan-id)
        loan (ok (- (unwrap-panic (get-loan-full-repayment-amount loan-id))
                   (get repaid-amount loan)))
        ERR-NOT-FOUND
    )
)

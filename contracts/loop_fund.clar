;; LoopFund - Microlending Platform Contract

;; Constants
[Previous constants remain unchanged...]

;; Events
(define-data-var last-event-id uint u0)
(define-map Events
    uint
    {
        event-type: (string-ascii 24),
        loan-id: (optional uint),
        user: principal,
        amount: (optional uint),
        timestamp: uint
    }
)

;; Remove unused map
;; (define-map UserLoans principal (list 10 uint))

;; Private Functions
(define-private (log-event (event-type (string-ascii 24)) (loan-id (optional uint)) (amount (optional uint)))
    (let ((event-id (+ (var-get last-event-id) u1)))
        (var-set last-event-id event-id)
        (map-set Events event-id {
            event-type: event-type,
            loan-id: loan-id,
            user: tx-sender,
            amount: amount,
            timestamp: block-height
        })
        event-id
    )
)

(define-private (calculate-credit-score (user principal))
    (match (map-get? UserScores user)
        score-data (ok (get score score-data))
        (ok u500) ;; Default starting score
    )
)

(define-private (update-platform-stats (loan-id uint) (status uint))
    (let ((stats (unwrap! (map-get? PlatformStats u0) (ok false))))
        (map-set PlatformStats u0
            (merge stats {
                active-loans: (if (is-eq status LOAN-STATUS-FUNDED)
                    (+ (get active-loans stats) u1)
                    (- (get active-loans stats) u1)
                ),
                total-volume: (+ (get total-volume stats) 
                    (unwrap! (get-loan-amount loan-id) u0))
            })
        )
        (ok true)
    )
)

[Previous private functions remain unchanged...]

;; Public Functions
(define-public (create-loan-request (amount uint) (interest-rate uint) (term-length uint) (collateral uint))
    (let (
        (loan-id (get-next-loan-id))
        (user-score (unwrap! (calculate-credit-score tx-sender) ERR-INVALID-SCORE))
    )
        (asserts! (validate-loan-params amount interest-rate term-length) ERR-INVALID-PARAMS)
        (asserts! (>= (* collateral u100) (* amount u50)) ERR-INSUFFICIENT-COLLATERAL)
        (asserts! (>= user-score u400) ERR-INVALID-SCORE) ;; Minimum credit score requirement
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
                credit-score: user-score,
                early-repayment-bonus: u0
            }
        )
        (map-set PlatformStats u0 
            {
                total-loans: (+ (var-get total-loans-created) u1),
                active-loans: u0,
                total-volume: u0,
                default-rate: u0
            }
        )
        (log-event "loan-created" (some loan-id) (some amount))
        (ok loan-id)
    )
)

[Previous public functions remain unchanged...]

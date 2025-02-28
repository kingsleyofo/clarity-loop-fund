;; LoopFund - Microlending Platform Contract

;; Constants
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-FUNDED (err u401))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-UNAUTHORIZED (err u403))
(define-constant ERR-LOAN-NOT-ACTIVE (err u405))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u406))
(define-constant ERR-INVALID-SCORE (err u407))
(define-constant ERR-INVALID-PARAMS (err u408))

;; New constants for safety limits
(define-constant MAX-LOAN-AMOUNT u100000000000) ;; 100,000 STX
(define-constant MAX-INTEREST-RATE u50) ;; 50%
(define-constant MIN-TERM-LENGTH u144) ;; ~1 day
(define-constant MAX-TERM-LENGTH u52560) ;; ~365 days

;; Data Variables
(define-data-var next-loan-id uint u0)
(define-data-var total-loans-created uint u0)
(define-data-var total-loans-funded uint u0)

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
        credit-score: uint,
        early-repayment-bonus: uint
    }
)

(define-map UserScores
    principal
    {
        score: uint,
        loans-completed: uint,
        loans-defaulted: uint,
        total-borrowed: uint,
        total-repaid: uint
    }
)

(define-map UserLoans
    principal
    (list 10 uint)
)

;; New map for platform statistics
(define-map PlatformStats
    uint
    {
        total-loans: uint,
        active-loans: uint,
        total-volume: uint,
        default-rate: uint
    }
)

;; Private Functions
(define-private (get-next-loan-id)
    (let ((current-id (var-get next-loan-id)))
        (var-set next-loan-id (+ current-id u1))
        (var-set total-loans-created (+ (var-get total-loans-created) u1))
        current-id
    )
)

(define-private (validate-loan-params (amount uint) (interest-rate uint) (term-length uint))
    (and
        (<= amount MAX-LOAN-AMOUNT)
        (<= interest-rate MAX-INTEREST-RATE)
        (>= term-length MIN-TERM-LENGTH)
        (<= term-length MAX-TERM-LENGTH)
    )
)

(define-private (calculate-early-repayment-bonus (remaining-blocks uint) (original-term uint))
    (let ((bonus-percentage (/ (* remaining-blocks u10) original-term)))
        (min bonus-percentage u5) ;; Max 5% bonus
    )
)

;; ... [Previous private functions remain unchanged]

;; Public Functions
(define-public (create-loan-request (amount uint) (interest-rate uint) (term-length uint) (collateral uint))
    (let (
        (loan-id (get-next-loan-id))
        (user-score (unwrap! (calculate-credit-score tx-sender) ERR-INVALID-SCORE))
    )
        (asserts! (validate-loan-params amount interest-rate term-length) ERR-INVALID-PARAMS)
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
                credit-score: user-score,
                early-repayment-bonus: u0
            }
        )
        (ok loan-id)
    )
)

;; ... [Other existing functions remain unchanged]

;; New public functions
(define-public (extend-loan-term (loan-id uint) (additional-blocks uint))
    (let (
        (loan (unwrap! (map-get? Loans loan-id) ERR-NOT-FOUND))
        (new-term-length (+ (get term-length loan) additional-blocks))
    )
        (asserts! (is-eq tx-sender (get borrower loan)) ERR-UNAUTHORIZED)
        (asserts! (<= new-term-length MAX-TERM-LENGTH) ERR-INVALID-PARAMS)
        
        (map-set Loans loan-id
            (merge loan {
                term-length: new-term-length
            })
        )
        (ok true)
    )
)

;; New read-only functions
(define-read-only (get-platform-stats)
    (let ((total-loans (var-get total-loans-created))
          (funded-loans (var-get total-loans-funded)))
        (some {
            total-loans: total-loans,
            active-loans: funded-loans,
            total-volume: u0, ;; To be implemented
            default-rate: u0  ;; To be implemented
        })
    )
)

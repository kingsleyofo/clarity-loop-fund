;; LoopFund - Microlending Platform Contract

;; Constants
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-FUNDED (err u401))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-UNAUTHORIZED (err u403))
(define-constant ERR-LOAN-NOT-ACTIVE (err u405))

;; Data Variables
(define-data-var next-loan-id uint u0)

;; Define loan status values
(define-constant LOAN-STATUS-REQUESTED u0)
(define-constant LOAN-STATUS-FUNDED u1)
(define-constant LOAN-STATUS-REPAID u2)
(define-constant LOAN-STATUS-DEFAULTED u3)

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
        repaid-amount: uint
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

;; Public Functions
(define-public (create-loan-request (amount uint) (interest-rate uint) (term-length uint))
    (let ((loan-id (get-next-loan-id)))
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
                repaid-amount: u0
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
        (map-set Loans
            loan-id
            (merge loan {
                repaid-amount: (+ (get repaid-amount loan) payment),
                status: (if (>= (+ (get repaid-amount loan) payment) 
                              (+ (get amount loan) 
                                 (/ (* (get amount loan) (get interest-rate loan)) u100)))
                          LOAN-STATUS-REPAID
                          LOAN-STATUS-FUNDED)
            })
        )
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-loan (loan-id uint))
    (map-get? Loans loan-id)
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
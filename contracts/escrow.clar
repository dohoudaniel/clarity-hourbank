;; Escrow Contract
;; Manages time credit deposits and releases for bookings

(use-trait token-trait .sip010-trait.sip010-trait)

(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INSUFFICIENT_BALANCE (err u401))
(define-constant ERR_ESCROW_NOT_FOUND (err u402))
(define-constant ERR_INVALID_AMOUNT (err u403))

;; Escrow data structure
(define-map escrows uint {
  booking-id: uint,
  requester: principal,
  provider: principal,
  amount: uint,
  released: bool,
  created-at: uint
})

(define-data-var next-escrow-id uint u1)

;; Deposit credits into escrow
(define-public (deposit-escrow (booking-id uint) (provider principal) (amount uint) (token <token-trait>))
  (let ((escrow-id (var-get next-escrow-id)))
    (if (> amount u0)
      (match (contract-call? token transfer amount tx-sender (as-contract tx-sender) none)
        success (begin
          (map-set escrows escrow-id {
            booking-id: booking-id,
            requester: tx-sender,
            provider: provider,
            amount: amount,
            released: false,
            created-at: stacks-block-height
          })
          (var-set next-escrow-id (+ escrow-id u1))
          (ok escrow-id))
        error ERR_INSUFFICIENT_BALANCE)
      ERR_INVALID_AMOUNT)))

;; Release escrowed credits to provider
(define-public (release-escrow (escrow-id uint) (token <token-trait>))
  (match (map-get? escrows escrow-id)
    escrow-data
      (if (and (is-eq tx-sender (get requester escrow-data))
               (not (get released escrow-data)))
        (match (as-contract (contract-call? token transfer (get amount escrow-data) tx-sender (get provider escrow-data) none))
          success (begin
            (map-set escrows escrow-id (merge escrow-data { released: true }))
            (ok true))
          error (err error))
        ERR_UNAUTHORIZED)
    ERR_ESCROW_NOT_FOUND))

;; Refund escrowed credits to requester (dispute resolution)
(define-public (refund-escrow (escrow-id uint) (token <token-trait>))
  (match (map-get? escrows escrow-id)
    escrow-data
      (if (not (get released escrow-data))
        (match (as-contract (contract-call? token transfer (get amount escrow-data) tx-sender (get requester escrow-data) none))
          success (begin
            (map-set escrows escrow-id (merge escrow-data { released: true }))
            (ok true))
          error (err error))
        ERR_UNAUTHORIZED)
    ERR_ESCROW_NOT_FOUND))

;; Get escrow details
(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrows escrow-id))
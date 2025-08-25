;; Dispute Resolver Contract
;; Handles disputes and arbitration for bookings

(define-constant ERR_UNAUTHORIZED (err u700))
(define-constant ERR_DISPUTE_NOT_FOUND (err u701))
(define-constant ERR_DISPUTE_EXISTS (err u702))
(define-constant ERR_INVALID_OUTCOME (err u703))

;; Dispute outcomes
(define-constant OUTCOME_PENDING u0)
(define-constant OUTCOME_PROVIDER_WINS u1)
(define-constant OUTCOME_REQUESTER_WINS u2)

;; Dispute data structure
(define-map disputes uint {
  booking-id: uint,
  requester: principal,
  provider: principal,
  reason: (string-ascii 512),
  outcome: uint,
  arbitrator: (optional principal),
  created-at: uint,
  resolved-at: (optional uint)
})

(define-data-var next-dispute-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Raise a dispute
(define-public (raise-dispute (booking-id uint) (provider principal) (reason (string-ascii 512)))
  (let ((dispute-id (var-get next-dispute-id)))
    (map-set disputes dispute-id {
      booking-id: booking-id,
      requester: tx-sender,
      provider: provider,
      reason: reason,
      outcome: OUTCOME_PENDING,
      arbitrator: none,
      created-at: block-height,
      resolved-at: none
    })
    (var-set next-dispute-id (+ dispute-id u1))
    (ok dispute-id)))

;; Resolve dispute (arbitrator only)
(define-public (resolve-dispute (dispute-id uint) (outcome uint))
  (if (is-eq tx-sender (var-get contract-owner))
    (if (or (is-eq outcome OUTCOME_PROVIDER_WINS) (is-eq outcome OUTCOME_REQUESTER_WINS))
      (match (map-get? disputes dispute-id)
        dispute-data (begin
          (map-set disputes dispute-id (merge dispute-data {
            outcome: outcome,
            arbitrator: (some tx-sender),
            resolved-at: (some block-height)
          }))
          (ok true))
        ERR_DISPUTE_NOT_FOUND)
      ERR_INVALID_OUTCOME)
    ERR_UNAUTHORIZED))

;; Get dispute details
(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes dispute-id))
;; Dispute Resolver Contract
;; Handles disputes and arbitration for bookings

(define-constant ERR_UNAUTHORIZED (err u700))
(define-constant ERR_DISPUTE_NOT_FOUND (err u701))
(define-constant ERR_DISPUTE_EXISTS (err u702))
(define-constant ERR_INVALID_OUTCOME (err u703))
(define-constant ERR_INVALID_INPUT (err u704))

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

;; Input validation helpers
(define-private (is-valid-amount (amount uint))
  (> amount u0))

(define-private (is-valid-principal (principal principal))
  (not (is-eq principal 'SP000000000000000000002Q6VF78)))

(define-private (is-valid-reason (reason (string-ascii 512)))
  (> (len reason) u0))

(define-private (is-valid-outcome (outcome uint))
  (or (is-eq outcome OUTCOME_PENDING)
      (is-eq outcome OUTCOME_PROVIDER_WINS)
      (is-eq outcome OUTCOME_REQUESTER_WINS)))

(define-private (is-valid-dispute-id (dispute-id uint))
  (> dispute-id u0))

;; Raise a dispute
(define-public (raise-dispute (booking-id uint) (provider principal) (reason (string-ascii 512)))
  (let ((dispute-id (var-get next-dispute-id)))
    (begin
      ;; Validate inputs
      (asserts! (is-valid-amount booking-id) ERR_INVALID_INPUT)
      (asserts! (is-valid-principal provider) ERR_INVALID_INPUT)
      (asserts! (is-valid-reason reason) ERR_INVALID_INPUT)

      (map-set disputes dispute-id {
        booking-id: booking-id,
        requester: tx-sender,
        provider: provider,
        reason: reason,
        outcome: OUTCOME_PENDING,
        arbitrator: none,
        created-at: stacks-block-height,
        resolved-at: none
      })
      (var-set next-dispute-id (+ dispute-id u1))
      (ok dispute-id))))

;; Resolve dispute (arbitrator only)
(define-public (resolve-dispute (dispute-id uint) (outcome uint))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-dispute-id dispute-id) ERR_INVALID_INPUT)
    (asserts! (is-valid-outcome outcome) ERR_INVALID_OUTCOME)
    (asserts! (not (is-eq outcome OUTCOME_PENDING)) ERR_INVALID_OUTCOME)

    (if (is-eq tx-sender (var-get contract-owner))
      (match (map-get? disputes dispute-id)
        dispute-data (begin
          (map-set disputes dispute-id (merge dispute-data {
            outcome: outcome,
            arbitrator: (some tx-sender),
            resolved-at: (some stacks-block-height)
          }))
          (ok true))
        ERR_DISPUTE_NOT_FOUND)
      ERR_UNAUTHORIZED)))

;; Get dispute details
(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes dispute-id))
;; Booking Manager Contract
;; Handles booking creation, acceptance, and status management

(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_BOOKING_NOT_FOUND (err u301))
(define-constant ERR_INVALID_STATUS (err u302))
(define-constant ERR_USER_NOT_REGISTERED (err u303))
(define-constant ERR_INVALID_INPUT (err u304))

;; Booking status constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_ACCEPTED u1)
(define-constant STATUS_DELIVERED u2)
(define-constant STATUS_APPROVED u3)
(define-constant STATUS_DISPUTED u4)

;; Booking data structure
(define-map bookings uint {
  requester: principal,
  provider: principal,
  skill-id: uint,
  hours: uint,
  total-credits: uint,
  status: uint,
  created-at: uint,
  accepted-at: (optional uint),
  delivered-at: (optional uint)
})

(define-data-var next-booking-id uint u1)

;; Input validation helpers
(define-private (is-valid-principal (principal principal))
  (not (is-eq principal 'SP000000000000000000002Q6VF78)))

(define-private (is-valid-amount (amount uint))
  (> amount u0))

(define-private (is-valid-booking-id (booking-id uint))
  (> booking-id u0))

(define-private (is-valid-status (status uint))
  (or (is-eq status STATUS_PENDING)
      (is-eq status STATUS_ACCEPTED)
      (is-eq status STATUS_DELIVERED)
      (is-eq status STATUS_APPROVED)
      (is-eq status STATUS_DISPUTED)))

;; Create a new booking
(define-public (create-booking (provider principal) (skill-id uint) (hours uint) (total-credits uint))
  (let ((booking-id (var-get next-booking-id)))
    (begin
      ;; Validate inputs
      (asserts! (is-valid-principal provider) ERR_INVALID_INPUT)
      (asserts! (is-valid-amount skill-id) ERR_INVALID_INPUT)
      (asserts! (is-valid-amount hours) ERR_INVALID_INPUT)
      (asserts! (is-valid-amount total-credits) ERR_INVALID_INPUT)
      (asserts! (not (is-eq tx-sender provider)) ERR_UNAUTHORIZED)

      (map-set bookings booking-id {
        requester: tx-sender,
        provider: provider,
        skill-id: skill-id,
        hours: hours,
        total-credits: total-credits,
        status: STATUS_PENDING,
        created-at: stacks-block-height,
        accepted-at: none,
        delivered-at: none
      })
      (var-set next-booking-id (+ booking-id u1))
      (ok booking-id))))

;; Accept a booking (provider only)
(define-public (accept-booking (booking-id uint))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-booking-id booking-id) ERR_INVALID_INPUT)

    (match (map-get? bookings booking-id)
      booking-data
        (if (and (is-eq tx-sender (get provider booking-data))
                 (is-eq (get status booking-data) STATUS_PENDING))
          (begin
            (map-set bookings booking-id (merge booking-data {
              status: STATUS_ACCEPTED,
              accepted-at: (some stacks-block-height)
            }))
            (ok true))
          ERR_UNAUTHORIZED)
      ERR_BOOKING_NOT_FOUND)))

;; Mark service as delivered (provider only)
(define-public (mark-delivered (booking-id uint))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-booking-id booking-id) ERR_INVALID_INPUT)

    (match (map-get? bookings booking-id)
      booking-data
        (if (and (is-eq tx-sender (get provider booking-data))
                 (is-eq (get status booking-data) STATUS_ACCEPTED))
          (begin
            (map-set bookings booking-id (merge booking-data {
              status: STATUS_DELIVERED,
              delivered-at: (some stacks-block-height)
            }))
            (ok true))
          ERR_UNAUTHORIZED)
      ERR_BOOKING_NOT_FOUND)))

;; Approve service (requester only)
(define-public (approve-service (booking-id uint))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-booking-id booking-id) ERR_INVALID_INPUT)

    (match (map-get? bookings booking-id)
      booking-data
        (if (and (is-eq tx-sender (get requester booking-data))
                 (is-eq (get status booking-data) STATUS_DELIVERED))
          (begin
            (map-set bookings booking-id (merge booking-data { status: STATUS_APPROVED }))
            (ok true))
          ERR_UNAUTHORIZED)
      ERR_BOOKING_NOT_FOUND)))

;; Get booking details
(define-read-only (get-booking (booking-id uint))
  (map-get? bookings booking-id))

;; Update booking status (internal use)
(define-public (update-booking-status (booking-id uint) (new-status uint))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-booking-id booking-id) ERR_INVALID_INPUT)
    (asserts! (is-valid-status new-status) ERR_INVALID_STATUS)

    (match (map-get? bookings booking-id)
      booking-data
        (begin
          (map-set bookings booking-id (merge booking-data { status: new-status }))
          (ok true))
      ERR_BOOKING_NOT_FOUND)))
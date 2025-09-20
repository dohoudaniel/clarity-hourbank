;; Analytics Contract
;; Tracks system metrics, statistics, and performance data for the HourBank platform

(define-constant ERR_UNAUTHORIZED (err u700))
(define-constant ERR_INVALID_INPUT (err u701))
(define-constant ERR_DATA_NOT_FOUND (err u702))

;; Contract owner for administrative functions
(define-data-var contract-owner principal tx-sender)

;; Global system metrics
(define-data-var total-bookings uint u0)
(define-data-var total-completed-bookings uint u0)
(define-data-var total-disputed-bookings uint u0)
(define-data-var total-users uint u0)
(define-data-var total-credits-issued uint u0)
(define-data-var total-credits-spent uint u0)
(define-data-var total-hours-booked uint u0)
(define-data-var total-hours-completed uint u0)

;; Daily metrics tracking
(define-map daily-metrics uint {
  date: uint,
  bookings-created: uint,
  bookings-completed: uint,
  credits-issued: uint,
  credits-spent: uint,
  new-users: uint,
  hours-booked: uint
})

;; User activity metrics
(define-map user-metrics principal {
  bookings-created: uint,
  bookings-completed: uint,
  total-hours-provided: uint,
  total-hours-requested: uint,
  credits-earned: uint,
  credits-spent: uint,
  last-activity: uint
})

;; Skill popularity metrics
(define-map skill-metrics uint {
  skill-id: uint,
  total-bookings: uint,
  total-hours: uint,
  average-rating: uint,
  total-credits: uint
})

;; Input validation helpers
(define-private (is-valid-principal (principal principal))
  (not (is-eq principal 'SP000000000000000000002Q6VF78)))

(define-private (is-valid-amount (amount uint))
  (> amount u0))

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner)))

;; Administrative functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal new-owner) ERR_INVALID_INPUT)
    (var-set contract-owner new-owner)
    (ok true)))

;; Booking metrics tracking
(define-public (record-booking-created (booking-id uint) (requester principal) (hours uint) (credits uint))
  (begin
    (asserts! (is-valid-amount booking-id) ERR_INVALID_INPUT)
    (asserts! (is-valid-principal requester) ERR_INVALID_INPUT)
    (asserts! (is-valid-amount hours) ERR_INVALID_INPUT)
    (asserts! (is-valid-amount credits) ERR_INVALID_INPUT)
    
    ;; Update global metrics
    (var-set total-bookings (+ (var-get total-bookings) u1))
    (var-set total-hours-booked (+ (var-get total-hours-booked) hours))
    
    ;; Update user metrics
    (let ((current-metrics (default-to 
                           {bookings-created: u0, bookings-completed: u0, total-hours-provided: u0, 
                            total-hours-requested: u0, credits-earned: u0, credits-spent: u0, last-activity: u0}
                           (map-get? user-metrics requester))))
      (map-set user-metrics requester 
        (merge current-metrics {
          bookings-created: (+ (get bookings-created current-metrics) u1),
          total-hours-requested: (+ (get total-hours-requested current-metrics) hours),
          credits-spent: (+ (get credits-spent current-metrics) credits),
          last-activity: stacks-block-height
        })))
    
    (ok true)))

(define-public (record-booking-completed (booking-id uint) (provider principal) (hours uint) (credits uint))
  (begin
    (asserts! (is-valid-amount booking-id) ERR_INVALID_INPUT)
    (asserts! (is-valid-principal provider) ERR_INVALID_INPUT)
    (asserts! (is-valid-amount hours) ERR_INVALID_INPUT)
    (asserts! (is-valid-amount credits) ERR_INVALID_INPUT)
    
    ;; Update global metrics
    (var-set total-completed-bookings (+ (var-get total-completed-bookings) u1))
    (var-set total-hours-completed (+ (var-get total-hours-completed) hours))
    
    ;; Update provider metrics
    (let ((current-metrics (default-to 
                           {bookings-created: u0, bookings-completed: u0, total-hours-provided: u0, 
                            total-hours-requested: u0, credits-earned: u0, credits-spent: u0, last-activity: u0}
                           (map-get? user-metrics provider))))
      (map-set user-metrics provider 
        (merge current-metrics {
          bookings-completed: (+ (get bookings-completed current-metrics) u1),
          total-hours-provided: (+ (get total-hours-provided current-metrics) hours),
          credits-earned: (+ (get credits-earned current-metrics) credits),
          last-activity: stacks-block-height
        })))
    
    (ok true)))

(define-public (record-dispute (booking-id uint))
  (begin
    (asserts! (is-valid-amount booking-id) ERR_INVALID_INPUT)
    (var-set total-disputed-bookings (+ (var-get total-disputed-bookings) u1))
    (ok true)))

(define-public (record-new-user (user principal))
  (begin
    (asserts! (is-valid-principal user) ERR_INVALID_INPUT)
    (var-set total-users (+ (var-get total-users) u1))
    (ok true)))

;; Read-only functions for analytics
(define-read-only (get-global-metrics)
  {
    total-bookings: (var-get total-bookings),
    total-completed-bookings: (var-get total-completed-bookings),
    total-disputed-bookings: (var-get total-disputed-bookings),
    total-users: (var-get total-users),
    total-credits-issued: (var-get total-credits-issued),
    total-credits-spent: (var-get total-credits-spent),
    total-hours-booked: (var-get total-hours-booked),
    total-hours-completed: (var-get total-hours-completed)
  })

(define-read-only (get-user-metrics (user principal))
  (map-get? user-metrics user))

(define-read-only (get-skill-metrics (skill-id uint))
  (map-get? skill-metrics skill-id))

(define-read-only (get-completion-rate)
  (if (> (var-get total-bookings) u0)
    (/ (* (var-get total-completed-bookings) u100) (var-get total-bookings))
    u0))

(define-read-only (get-dispute-rate)
  (if (> (var-get total-bookings) u0)
    (/ (* (var-get total-disputed-bookings) u100) (var-get total-bookings))
    u0))

(define-read-only (get-contract-owner)
  (var-get contract-owner))

;; Reputation Contract
;; Manages user reputation scores and feedback

(define-constant ERR_UNAUTHORIZED (err u600))
(define-constant ERR_USER_NOT_FOUND (err u601))
(define-constant ERR_INVALID_RATING (err u602))
(define-constant ERR_INVALID_INPUT (err u603))

;; Reputation data
(define-map reputation principal {
  total-score: uint,
  total-ratings: uint,
  average-rating: uint
})

;; Individual ratings
(define-map ratings { rater: principal, rated: principal, booking-id: uint } {
  score: uint,
  comment: (string-ascii 256),
  created-at: uint
})

;; Input validation helpers
(define-private (is-valid-principal (principal principal))
  (not (is-eq principal 'SP000000000000000000002Q6VF78)))

(define-private (is-valid-booking-id (booking-id uint))
  (> booking-id u0))

(define-private (is-valid-score (score uint))
  (and (>= score u1) (<= score u5)))

(define-private (is-valid-comment (comment (string-ascii 256)))
  (> (len comment) u0))

;; Add a rating (1-5 scale)
(define-public (add-rating (rated principal) (booking-id uint) (score uint) (comment (string-ascii 256)))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-principal rated) ERR_INVALID_INPUT)
    (asserts! (is-valid-booking-id booking-id) ERR_INVALID_INPUT)
    (asserts! (is-valid-score score) ERR_INVALID_RATING)
    (asserts! (is-valid-comment comment) ERR_INVALID_INPUT)

    (let ((current-rep (default-to { total-score: u0, total-ratings: u0, average-rating: u0 } (map-get? reputation rated))))
      (begin
        ;; Store individual rating
        (map-set ratings { rater: tx-sender, rated: rated, booking-id: booking-id } {
          score: score,
          comment: comment,
          created-at: stacks-block-height
        })
        ;; Update aggregate reputation
        (let ((new-total-score (+ (get total-score current-rep) score))
              (new-total-ratings (+ (get total-ratings current-rep) u1)))
          (map-set reputation rated {
            total-score: new-total-score,
            total-ratings: new-total-ratings,
            average-rating: (/ new-total-score new-total-ratings)
          }))
        (ok true)))))

;; Get user reputation
(define-read-only (get-reputation (user principal))
  (map-get? reputation user))

;; Get specific rating
(define-read-only (get-rating (rater principal) (rated principal) (booking-id uint))
  (map-get? ratings { rater: rater, rated: rated, booking-id: booking-id }))
;; Reputation Contract
;; Manages user reputation scores and feedback

(define-constant ERR_UNAUTHORIZED (err u600))
(define-constant ERR_USER_NOT_FOUND (err u601))
(define-constant ERR_INVALID_RATING (err u602))

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

;; Add a rating (1-5 scale)
(define-public (add-rating (rated principal) (booking-id uint) (score uint) (comment (string-ascii 256)))
  (if (and (>= score u1) (<= score u5))
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
        (ok true)))
    ERR_INVALID_RATING))

;; Get user reputation
(define-read-only (get-reputation (user principal))
  (map-get? reputation user))

;; Get specific rating
(define-read-only (get-rating (rater principal) (rated principal) (booking-id uint))
  (map-get? ratings { rater: rater, rated: rated, booking-id: booking-id }))
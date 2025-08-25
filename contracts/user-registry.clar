;; User Registry Contract
;; Manages user profiles and verification status

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_USER_EXISTS (err u101))
(define-constant ERR_USER_NOT_FOUND (err u102))

;; User profile data structure
(define-map users principal {
  name: (string-ascii 64),
  bio: (string-ascii 256),
  verified: bool,
  created-at: uint
})

;; Contract owner for verification
(define-data-var contract-owner principal tx-sender)

;; Register a new user
(define-public (register-user (name (string-ascii 64)) (bio (string-ascii 256)))
  (let ((user tx-sender))
    (if (is-some (map-get? users user))
      ERR_USER_EXISTS
      (begin
        (map-set users user {
          name: name,
          bio: bio,
          verified: false,
          created-at: stacks-block-height
        })
        (ok true)))))

;; Get user profile
(define-read-only (get-user (user principal))
  (map-get? users user))

;; Verify a user (owner only)
(define-public (verify-user (user principal))
  (if (is-eq tx-sender (var-get contract-owner))
    (match (map-get? users user)
      user-data (begin
        (map-set users user (merge user-data { verified: true }))
        (ok true))
      ERR_USER_NOT_FOUND)
    ERR_UNAUTHORIZED))

;; Check if user is registered
(define-read-only (is-user-registered (user principal))
  (is-some (map-get? users user)))
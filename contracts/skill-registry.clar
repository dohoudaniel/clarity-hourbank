;; Skill Registry Contract
;; Manages available skills and provider offerings

(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_SKILL_EXISTS (err u201))
(define-constant ERR_SKILL_NOT_FOUND (err u202))
(define-constant ERR_INVALID_INPUT (err u203))

;; Skill categories
(define-map skills uint {
  name: (string-ascii 64),
  description: (string-ascii 256),
  category: (string-ascii 32),
  creator: principal
})

;; Provider skill offerings
(define-map provider-skills { provider: principal, skill-id: uint } {
  hourly-rate: uint,
  available: bool,
  created-at: uint
})

(define-data-var next-skill-id uint u1)

;; Input validation helpers
(define-private (is-valid-string (str (string-ascii 64)))
  (> (len str) u0))

(define-private (is-valid-description (desc (string-ascii 256)))
  (> (len desc) u0))

(define-private (is-valid-category (cat (string-ascii 32)))
  (> (len cat) u0))

(define-private (is-valid-rate (rate uint))
  (> rate u0))

;; Create a new skill category
(define-public (create-skill (name (string-ascii 64)) (description (string-ascii 256)) (category (string-ascii 32)))
  (let ((skill-id (var-get next-skill-id)))
    (begin
      ;; Validate inputs
      (asserts! (is-valid-string name) ERR_INVALID_INPUT)
      (asserts! (is-valid-description description) ERR_INVALID_INPUT)
      (asserts! (is-valid-category category) ERR_INVALID_INPUT)

      (map-set skills skill-id {
        name: name,
        description: description,
        category: category,
        creator: tx-sender
      })
      (var-set next-skill-id (+ skill-id u1))
      (ok skill-id))))

;; Register as a provider for a skill
(define-public (register-provider (skill-id uint) (hourly-rate uint))
  (begin
    ;; Validate inputs
    (asserts! (> skill-id u0) ERR_INVALID_INPUT)
    (asserts! (is-valid-rate hourly-rate) ERR_INVALID_INPUT)

    (if (is-some (map-get? skills skill-id))
      (begin
        (map-set provider-skills { provider: tx-sender, skill-id: skill-id } {
          hourly-rate: hourly-rate,
          available: true,
          created-at: stacks-block-height
        })
        (ok true))
      ERR_SKILL_NOT_FOUND)))

;; Get skill info
(define-read-only (get-skill (skill-id uint))
  (map-get? skills skill-id))

;; Get provider offering
(define-read-only (get-provider-skill (provider principal) (skill-id uint))
  (map-get? provider-skills { provider: provider, skill-id: skill-id }))
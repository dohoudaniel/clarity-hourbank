;; Skill Registry Contract
;; Manages available skills and provider offerings

(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_SKILL_EXISTS (err u201))
(define-constant ERR_SKILL_NOT_FOUND (err u202))

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

;; Create a new skill category
(define-public (create-skill (name (string-ascii 64)) (description (string-ascii 256)) (category (string-ascii 32)))
  (let ((skill-id (var-get next-skill-id)))
    (map-set skills skill-id {
      name: name,
      description: description,
      category: category,
      creator: tx-sender
    })
    (var-set next-skill-id (+ skill-id u1))
    (ok skill-id)))

;; Register as a provider for a skill
(define-public (register-provider (skill-id uint) (hourly-rate uint))
  (if (is-some (map-get? skills skill-id))
    (begin
      (map-set provider-skills { provider: tx-sender, skill-id: skill-id } {
        hourly-rate: hourly-rate,
        available: true,
        created-at: block-height
      })
      (ok true))
    ERR_SKILL_NOT_FOUND))

;; Get skill info
(define-read-only (get-skill (skill-id uint))
  (map-get? skills skill-id))

;; Get provider offering
(define-read-only (get-provider-skill (provider principal) (skill-id uint))
  (map-get? provider-skills { provider: provider, skill-id: skill-id }))
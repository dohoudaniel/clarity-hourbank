;; Time Credit Token Contract
;; SIP-010 compatible token for time-banking credits

(impl-trait .sip010-trait.sip010-trait)

(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INSUFFICIENT_BALANCE (err u501))
(define-constant ERR_INVALID_AMOUNT (err u502))
(define-constant ERR_INVALID_PRINCIPAL (err u503))

;; Token metadata
(define-constant TOKEN_NAME "Time Credits")
(define-constant TOKEN_SYMBOL "TIME")
(define-constant TOKEN_DECIMALS u0)

;; Token balances
(define-map balances principal uint)
(define-data-var total-supply uint u0)
(define-data-var token-uri (optional (string-utf8 256)) none)

;; Contract owner for minting
(define-data-var contract-owner principal tx-sender)

;; Input validation helpers
(define-private (is-valid-amount (amount uint))
  (> amount u0))

(define-private (is-valid-principal (principal principal))
  (not (is-eq principal 'SP000000000000000000002Q6VF78)))

;; SIP-010 Functions
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-principal sender) ERR_INVALID_PRINCIPAL)
    (asserts! (is-valid-principal recipient) ERR_INVALID_PRINCIPAL)
    (asserts! (not (is-eq sender recipient)) ERR_INVALID_PRINCIPAL)

    (if (is-eq tx-sender sender)
      (transfer-helper amount sender recipient)
      ERR_UNAUTHORIZED)))

(define-private (transfer-helper (amount uint) (sender principal) (recipient principal))
  (let ((sender-balance (default-to u0 (map-get? balances sender))))
    (if (>= sender-balance amount)
      (begin
        (map-set balances sender (- sender-balance amount))
        (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount))
        (ok true))
      ERR_INSUFFICIENT_BALANCE)))

(define-read-only (get-name)
  (ok TOKEN_NAME))

(define-read-only (get-symbol)
  (ok TOKEN_SYMBOL))

(define-read-only (get-decimals)
  (ok TOKEN_DECIMALS))

(define-read-only (get-balance (who principal))
  (ok (default-to u0 (map-get? balances who))))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

;; Mint tokens (owner only)
(define-public (mint (amount uint) (recipient principal))
  (begin
    ;; Validate inputs
    (asserts! (is-valid-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-principal recipient) ERR_INVALID_PRINCIPAL)

    (if (is-eq tx-sender (var-get contract-owner))
      (begin
        (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount))
        (var-set total-supply (+ (var-get total-supply) amount))
        (ok true))
      ERR_UNAUTHORIZED)))
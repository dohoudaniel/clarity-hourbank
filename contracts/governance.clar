;; Governance Contract
;; Community governance system for HourBank platform parameters and upgrades

(define-constant ERR_UNAUTHORIZED (err u800))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u801))
(define-constant ERR_INVALID_INPUT (err u802))
(define-constant ERR_VOTING_ENDED (err u803))
(define-constant ERR_VOTING_ACTIVE (err u804))
(define-constant ERR_ALREADY_VOTED (err u805))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u806))
(define-constant ERR_PROPOSAL_EXECUTED (err u807))

;; Governance parameters
(define-data-var min-reputation-to-propose uint u100)
(define-data-var min-reputation-to-vote uint u10)
(define-data-var voting-period uint u1008) ;; ~7 days in blocks
(define-data-var execution-delay uint u144) ;; ~1 day in blocks
(define-data-var quorum-threshold uint u20) ;; 20% of total reputation
(define-data-var approval-threshold uint u60) ;; 60% approval needed

;; Contract owner and governance council
(define-data-var contract-owner principal tx-sender)
(define-data-var governance-active bool false)

;; Proposal types
(define-constant PROPOSAL_TYPE_PARAMETER u1)
(define-constant PROPOSAL_TYPE_UPGRADE u2)
(define-constant PROPOSAL_TYPE_EMERGENCY u3)

;; Proposal data structure
(define-map proposals uint {
  proposer: principal,
  title: (string-ascii 64),
  description: (string-ascii 256),
  proposal-type: uint,
  created-at: uint,
  voting-ends-at: uint,
  execution-available-at: uint,
  yes-votes: uint,
  no-votes: uint,
  total-voting-power: uint,
  executed: bool,
  cancelled: bool
})

(define-data-var next-proposal-id uint u1)

;; Voting records
(define-map votes { proposal-id: uint, voter: principal } {
  vote: bool,
  voting-power: uint,
  voted-at: uint
})

;; Input validation helpers
(define-private (is-valid-principal (principal principal))
  (not (is-eq principal 'SP000000000000000000002Q6VF78)))

(define-private (is-valid-string (str (string-ascii 64)))
  (and (> (len str) u0) (<= (len str) u64)))

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner)))

;; Get user reputation from reputation contract
(define-private (get-user-reputation (user principal))
  (match (contract-call? .reputation get-reputation user)
    reputation-data (get total-score reputation-data)
    u0))

;; Administrative functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal new-owner) ERR_INVALID_INPUT)
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (activate-governance)
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set governance-active true)
    (ok true)))

;; Proposal creation
(define-public (create-proposal 
  (title (string-ascii 64))
  (description (string-ascii 256))
  (proposal-type uint))
  (let ((proposer-reputation (get-user-reputation tx-sender))
        (proposal-id (var-get next-proposal-id))
        (current-block stacks-block-height))
    (begin
      (asserts! (var-get governance-active) ERR_UNAUTHORIZED)
      (asserts! (>= proposer-reputation (var-get min-reputation-to-propose)) ERR_INSUFFICIENT_REPUTATION)
      (asserts! (is-valid-string title) ERR_INVALID_INPUT)
      (asserts! (or (is-eq proposal-type PROPOSAL_TYPE_PARAMETER)
                    (is-eq proposal-type PROPOSAL_TYPE_UPGRADE)
                    (is-eq proposal-type PROPOSAL_TYPE_EMERGENCY)) ERR_INVALID_INPUT)
      
      (map-set proposals proposal-id {
        proposer: tx-sender,
        title: title,
        description: description,
        proposal-type: proposal-type,
        created-at: current-block,
        voting-ends-at: (+ current-block (var-get voting-period)),
        execution-available-at: (+ current-block (var-get voting-period) (var-get execution-delay)),
        yes-votes: u0,
        no-votes: u0,
        total-voting-power: u0,
        executed: false,
        cancelled: false
      })
      
      (var-set next-proposal-id (+ proposal-id u1))
      (ok proposal-id))))

;; Voting on proposals
(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (voter-reputation (get-user-reputation tx-sender))
        (current-block stacks-block-height))
    (begin
      (asserts! (var-get governance-active) ERR_UNAUTHORIZED)
      (asserts! (>= voter-reputation (var-get min-reputation-to-vote)) ERR_INSUFFICIENT_REPUTATION)
      (asserts! (<= current-block (get voting-ends-at proposal)) ERR_VOTING_ENDED)
      (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: tx-sender})) ERR_ALREADY_VOTED)
      (asserts! (not (get executed proposal)) ERR_PROPOSAL_EXECUTED)
      (asserts! (not (get cancelled proposal)) ERR_PROPOSAL_NOT_FOUND)
      
      ;; Record the vote
      (map-set votes {proposal-id: proposal-id, voter: tx-sender} {
        vote: vote,
        voting-power: voter-reputation,
        voted-at: current-block
      })
      
      ;; Update proposal vote counts
      (let ((updated-proposal 
             (if vote
               (merge proposal {
                 yes-votes: (+ (get yes-votes proposal) voter-reputation),
                 total-voting-power: (+ (get total-voting-power proposal) voter-reputation)
               })
               (merge proposal {
                 no-votes: (+ (get no-votes proposal) voter-reputation),
                 total-voting-power: (+ (get total-voting-power proposal) voter-reputation)
               }))))
        (map-set proposals proposal-id updated-proposal))
      
      (ok true))))

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter}))

(define-read-only (get-governance-parameters)
  {
    min-reputation-to-propose: (var-get min-reputation-to-propose),
    min-reputation-to-vote: (var-get min-reputation-to-vote),
    voting-period: (var-get voting-period),
    execution-delay: (var-get execution-delay),
    quorum-threshold: (var-get quorum-threshold),
    approval-threshold: (var-get approval-threshold),
    governance-active: (var-get governance-active)
  })

(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id))

(define-read-only (get-contract-owner)
  (var-get contract-owner))

(define-read-only (is-governance-active)
  (var-get governance-active))

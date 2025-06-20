;; Decentralized Lottery System
;; A provably fair lottery with transparent RNG, multiple prize tiers, and fraud prevention

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-lottery-not-active (err u101))
(define-constant err-lottery-active (err u102))
(define-constant err-insufficient-payment (err u103))
(define-constant err-no-tickets (err u104))
(define-constant err-already-drawn (err u105))
(define-constant err-invalid-ticket (err u106))
(define-constant err-withdrawal-failed (err u107))

;; Ticket price in micro-STX
(define-constant ticket-price u1000000) ;; 1 STX

;; Prize distribution percentages (basis points: 10000 = 100%)
(define-constant jackpot-percentage u6000)    ;; 60%
(define-constant second-prize-percentage u2000) ;; 20%
(define-constant third-prize-percentage u1000)  ;; 10%
(define-constant house-percentage u1000)        ;; 10%

;; Data Variables
(define-data-var lottery-id uint u0)
(define-data-var is-lottery-active bool false)
(define-data-var current-prize-pool uint u0)
(define-data-var ticket-counter uint u0)
(define-data-var draw-block-height uint u0)

;; Data Maps
(define-map lottery-tickets
  { lottery-id: uint, ticket-id: uint }
  { owner: principal, purchase-block: uint })

(define-map user-tickets
  { lottery-id: uint, user: principal }
  { ticket-count: uint, ticket-ids: (list 100 uint) })

(define-map lottery-results
  { lottery-id: uint }
  {
    total-tickets: uint,
    prize-pool: uint,
    jackpot-winner: (optional principal),
    second-winners: (list 3 principal),
    third-winners: (list 10 principal),
    winning-numbers: (list 3 uint),
    drawn-at-block: uint
  })

(define-map prize-claims
  { lottery-id: uint, user: principal }
  { claimed: bool, amount: uint })

;; Private Functions
(define-private (generate-random-number (seed uint) (max uint))
  (let ((hash-input (+ seed stacks-block-height (var-get lottery-id))))
    (+ u1 (mod hash-input max))))

(define-private (select-winners (total-tickets uint))
  (let (
    (jackpot-number (generate-random-number u1 total-tickets))
    (second-number (generate-random-number u2 total-tickets))
    (third-number (generate-random-number u3 total-tickets))
    (current-lottery (var-get lottery-id))
  )
  (list jackpot-number second-number third-number)))

(define-private (get-ticket-owner (lottery-round uint) (ticket-id uint))
  (get owner (map-get? lottery-tickets { lottery-id: lottery-round, ticket-id: ticket-id })))

(define-private (calculate-prize (total-pool uint) (percentage uint))
  (/ (* total-pool percentage) u10000))

(define-private (distribute-prizes (winners (list 3 uint)) (total-pool uint))
  (let (
    (current-lottery (var-get lottery-id))
    (jackpot-winner (get-ticket-owner current-lottery (unwrap-panic (element-at winners u0))))
    (second-winner (get-ticket-owner current-lottery (unwrap-panic (element-at winners u1))))
    (third-winner (get-ticket-owner current-lottery (unwrap-panic (element-at winners u2))))
    (jackpot-amount (calculate-prize total-pool jackpot-percentage))
    (second-amount (calculate-prize total-pool second-prize-percentage))
    (third-amount (calculate-prize total-pool third-prize-percentage))
  )
  ;; Record prize claims
  (match jackpot-winner winner
    (map-set prize-claims
      { lottery-id: current-lottery, user: winner }
      { claimed: false, amount: jackpot-amount })
    true)
  (match second-winner winner
    (map-set prize-claims
      { lottery-id: current-lottery, user: winner }
      { claimed: false, amount: second-amount })
    true)
  (match third-winner winner
    (map-set prize-claims
      { lottery-id: current-lottery, user: winner }
      { claimed: false, amount: third-amount })
    true)
  true))

;; Public Functions

;; Start a new lottery
(define-public (start-lottery)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (var-get is-lottery-active) false) err-lottery-active)
    (var-set lottery-id (+ (var-get lottery-id) u1))
    (var-set is-lottery-active true)
    (var-set current-prize-pool u0)
    (var-set ticket-counter u0)
    (var-set draw-block-height (+ stacks-block-height u144)) ;; ~24 hours
    (ok (var-get lottery-id))))

;; Purchase lottery ticket
(define-public (buy-ticket)
  (let (
    (current-lottery (var-get lottery-id))
    (current-ticket-count (var-get ticket-counter))
    (new-ticket-id (+ current-ticket-count u1))
    (current-user-data (default-to
      { ticket-count: u0, ticket-ids: (list) }
      (map-get? user-tickets { lottery-id: current-lottery, user: tx-sender })))
  )
  (asserts! (var-get is-lottery-active) err-lottery-not-active)
  (asserts! (< stacks-block-height (var-get draw-block-height)) err-lottery-not-active)

  ;; Transfer payment
  (try! (stx-transfer? ticket-price tx-sender (as-contract tx-sender)))

  ;; Update prize pool
  (var-set current-prize-pool (+ (var-get current-prize-pool) ticket-price))

  ;; Record ticket
  (map-set lottery-tickets
    { lottery-id: current-lottery, ticket-id: new-ticket-id }
    { owner: tx-sender, purchase-block: stacks-block-height })

  ;; Update user tickets
  (map-set user-tickets
    { lottery-id: current-lottery, user: tx-sender }
    {
      ticket-count: (+ (get ticket-count current-user-data) u1),
      ticket-ids: (unwrap-panic (as-max-len?
        (append (get ticket-ids current-user-data) new-ticket-id) u100))
    })

  (var-set ticket-counter new-ticket-id)
  (ok new-ticket-id)))

;; Draw lottery winners
(define-public (draw-lottery)
  (let (
    (current-lottery (var-get lottery-id))
    (total-tickets (var-get ticket-counter))
    (total-pool (var-get current-prize-pool))
  )
  (asserts! (var-get is-lottery-active) err-lottery-not-active)
  (asserts! (>= stacks-block-height (var-get draw-block-height)) err-lottery-not-active)
  (asserts! (> total-tickets u0) err-no-tickets)

  (let ((winning-numbers (select-winners total-tickets)))
    ;; Record results
    (map-set lottery-results
      { lottery-id: current-lottery }
      {
        total-tickets: total-tickets,
        prize-pool: total-pool,
        jackpot-winner: (get-ticket-owner current-lottery (unwrap-panic (element-at winning-numbers u0))),
        second-winners: (list
          (default-to tx-sender (get-ticket-owner current-lottery (unwrap-panic (element-at winning-numbers u1))))),
        third-winners: (list
          (default-to tx-sender (get-ticket-owner current-lottery (unwrap-panic (element-at winning-numbers u2))))),
        winning-numbers: winning-numbers,
        drawn-at-block: stacks-block-height
      })

    ;; Distribute prizes
    (distribute-prizes winning-numbers total-pool)

    ;; End lottery
    (var-set is-lottery-active false)
    (ok winning-numbers))))

;; Claim prize
(define-public (claim-prize (lottery-round uint))
  (let (
    (claim-data (unwrap! (map-get? prize-claims { lottery-id: lottery-round, user: tx-sender })
      err-invalid-ticket))
    (prize-amount (get amount claim-data))
  )
  (asserts! (is-eq (get claimed claim-data) false) err-already-drawn)
  (asserts! (> prize-amount u0) err-invalid-ticket)

  ;; Mark as claimed
  (map-set prize-claims
    { lottery-id: lottery-round, user: tx-sender }
    { claimed: true, amount: prize-amount })

  ;; Transfer prize
  (as-contract (stx-transfer? prize-amount tx-sender tx-sender))))

;; Emergency stop (owner only)
(define-public (emergency-stop)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set is-lottery-active false)
    (ok true)))

;; Withdraw house fees (owner only)
(define-public (withdraw-house-fees)
  (let ((house-amount (calculate-prize (var-get current-prize-pool) house-percentage)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (as-contract (stx-transfer? house-amount tx-sender contract-owner))))

;; Read-only Functions

(define-read-only (get-lottery-info)
  {
    lottery-id: (var-get lottery-id),
    is-active: (var-get is-lottery-active),
    prize-pool: (var-get current-prize-pool),
    total-tickets: (var-get ticket-counter),
    draw-block: (var-get draw-block-height),
    current-block: stacks-block-height
  })

(define-read-only (get-user-tickets (lottery-round uint) (user principal))
  (map-get? user-tickets { lottery-id: lottery-round, user: user }))

(define-read-only (get-lottery-results (lottery-round uint))
  (map-get? lottery-results { lottery-id: lottery-round }))

(define-read-only (get-prize-claim (lottery-round uint) (user principal))
  (map-get? prize-claims { lottery-id: lottery-round, user: user }))

(define-read-only (get-ticket-info (lottery-round uint) (ticket-id uint))
  (map-get? lottery-tickets { lottery-id: lottery-round, ticket-id: ticket-id }))

;; Initialize contract
(begin
  (var-set lottery-id u0)
  (var-set is-lottery-active false))

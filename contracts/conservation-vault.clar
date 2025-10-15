;; ForestFi Conservation Vault Contract
;; Manages forest conservation funding, carbon credits, and rewards

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_INSUFFICIENT_FUNDS (err u202))
(define-constant ERR_INVALID_AMOUNT (err u203))
(define-constant ERR_PROJECT_NOT_ACTIVE (err u204))
(define-constant ERR_PROJECT_EXPIRED (err u205))
(define-constant ERR_FUNDING_GOAL_REACHED (err u206))
(define-constant ERR_PROJECT_NOT_FOUND (err u207))
(define-constant ERR_INVALID_DURATION (err u208))
(define-constant ERR_EMERGENCY_ONLY (err u209))

;; Project status constants
(define-constant PROJECT_ACTIVE "active")
(define-constant PROJECT_FUNDED "funded")
(define-constant PROJECT_COMPLETED "completed")
(define-constant PROJECT_EXPIRED "expired")
(define-constant PROJECT_EMERGENCY "emergency")

;; Minimum funding amounts
(define-constant MIN_PROJECT_FUNDING u100000) ;; 1 STX minimum
(define-constant MIN_CONTRIBUTION u10000) ;; 0.1 STX minimum
(define-constant EMERGENCY_THRESHOLD u90) ;; Threat level for emergency funding

;; Data Variables
(define-data-var total-vault-balance uint u0)
(define-data-var total-conservation-projects uint u0)
(define-data-var total-funded-projects uint u0)
(define-data-var next-project-id uint u1)
(define-data-var total-carbon-credits-generated uint u0)
(define-data-var emergency-fund-balance uint u0)

;; Data Maps
(define-map conservation-projects
  { project-id: uint }
  {
    forest-token-id: uint,
    creator: principal,
    title: (string-utf8 100),
    description: (string-utf8 400),
    funding-goal: uint,
    current-funding: uint,
    deadline: uint,
    status: (string-ascii 20),
    conservation-actions: (string-utf8 300),
    expected-carbon-credits: uint,
    biodiversity-targets: uint,
    created-at: uint,
    contributors-count: uint,
    completion-percentage: uint
  }
)

(define-map project-contributions
  { project-id: uint, contributor: principal }
  {
    amount: uint,
    contribution-date: uint,
    motivation: (string-utf8 200),
    carbon-credits-earned: uint
  }
)

(define-map guardian-rewards
  { guardian: principal }
  {
    total-earned: uint,
    last-reward: uint,
    performance-score: uint,
    forests-saved: uint,
    carbon-credits-generated: uint
  }
)

(define-map carbon-credits
  { credit-id: uint }
  {
    forest-token-id: uint,
    owner: principal,
    amount-tons: uint,
    generated-date: uint,
    verification-status: (string-ascii 20),
    price-per-ton: uint
  }
)

(define-map emergency-alerts
  { forest-token-id: uint }
  {
    alert-date: uint,
    threat-level: uint,
    required-funding: uint,
    current-emergency-funding: uint,
    resolved: bool
  }
)

(define-map forest-impact-metrics
  { forest-token-id: uint }
  {
    hectares-protected: uint,
    co2-sequestered: uint,
    biodiversity-preserved: uint,
    community-jobs-created: uint,
    deforestation-prevented: uint,
    last-updated: uint
  }
)

;; Conservation Project Management
(define-public (create-conservation-project
    (forest-token-id uint)
    (title (string-utf8 100))
    (description (string-utf8 400))
    (funding-goal uint)
    (duration-blocks uint)
    (conservation-actions (string-utf8 300))
    (expected-carbon-credits uint)
    (biodiversity-targets uint)
  )
  (let (
    (project-id (var-get next-project-id))
  )
    ;; Validate inputs
    (asserts! (>= funding-goal MIN_PROJECT_FUNDING) ERR_INVALID_AMOUNT)
    (asserts! (> (len title) u0) ERR_INVALID_AMOUNT)
    (asserts! (and (> duration-blocks u0) (<= duration-blocks u52560)) ERR_INVALID_DURATION) ;; Max 1 year
    (asserts! (> expected-carbon-credits u0) ERR_INVALID_AMOUNT)
    
    ;; Create conservation project
    (map-set conservation-projects
      { project-id: project-id }
      {
        forest-token-id: forest-token-id,
        creator: tx-sender,
        title: title,
        description: description,
        funding-goal: funding-goal,
        current-funding: u0,
        deadline: (+ stacks-block-height duration-blocks),
        status: PROJECT_ACTIVE,
        conservation-actions: conservation-actions,
        expected-carbon-credits: expected-carbon-credits,
        biodiversity-targets: biodiversity-targets,
        created-at: stacks-block-height,
        contributors-count: u0,
        completion-percentage: u0
      }
    )
    
    ;; Update counters
    (var-set next-project-id (+ project-id u1))
    (var-set total-conservation-projects (+ (var-get total-conservation-projects) u1))
    
    (ok project-id)
  )
)

(define-public (fund-forest-protection
    (project-id uint)
    (amount uint)
    (motivation (string-utf8 200))
  )
  (let (
    (project (unwrap! (map-get? conservation-projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND))
    (contribution-key { project-id: project-id, contributor: tx-sender })
    (existing-contribution (map-get? project-contributions contribution-key))
  )
    ;; Validate project is active
    (asserts! (is-eq (get status project) PROJECT_ACTIVE) ERR_PROJECT_NOT_ACTIVE)
    (asserts! (<= stacks-block-height (get deadline project)) ERR_PROJECT_EXPIRED)
    
    ;; Check funding goal not exceeded
    (asserts! (< (get current-funding project) (get funding-goal project)) ERR_FUNDING_GOAL_REACHED)
    
    ;; Validate amount
    (asserts! (>= amount MIN_CONTRIBUTION) ERR_INVALID_AMOUNT)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Calculate carbon credits earned (simplified formula)
    (let (
      (carbon-credits-earned (/ (* amount (get expected-carbon-credits project)) (get funding-goal project)))
    )
      ;; Record/update contribution
      (map-set project-contributions
        contribution-key
        {
          amount: (+ amount (default-to u0 (get amount existing-contribution))),
          contribution-date: stacks-block-height,
          motivation: motivation,
          carbon-credits-earned: (+ carbon-credits-earned (default-to u0 (get carbon-credits-earned existing-contribution)))
        }
      )
    )
    
    ;; Update project funding
    (let (
      (new-funding (+ (get current-funding project) amount))
      (completion-pct (/ (* new-funding u100) (get funding-goal project)))
      (is-new-contributor (is-none existing-contribution))
    )
      (map-set conservation-projects
        { project-id: project-id }
        (merge project {
          current-funding: new-funding,
          contributors-count: (if is-new-contributor 
                               (+ (get contributors-count project) u1)
                               (get contributors-count project)),
          completion-percentage: (if (<= completion-pct u100) completion-pct u100),
          status: (if (>= new-funding (get funding-goal project)) PROJECT_FUNDED PROJECT_ACTIVE)
        })
      )
    )
    
    ;; Update global balance
    (var-set total-vault-balance (+ (var-get total-vault-balance) amount))
    
    ;; If project is now funded, update counter
    (if (>= (+ (get current-funding project) amount) (get funding-goal project))
      (var-set total-funded-projects (+ (var-get total-funded-projects) u1))
      false
    )
    
    (ok true)
  )
)

;; Guardian Reward System
(define-public (distribute-rewards (guardian principal) (reward-amount uint) (performance-bonus uint))
  (let (
    (current-rewards (default-to 
      { total-earned: u0, last-reward: u0, performance-score: u50, forests-saved: u0, carbon-credits-generated: u0 }
      (map-get? guardian-rewards { guardian: guardian })
    ))
  )
    ;; Only contract owner can distribute rewards
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    ;; Validate reward amount
    (asserts! (> reward-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= reward-amount (var-get total-vault-balance)) ERR_INSUFFICIENT_FUNDS)
    
    ;; Transfer reward to guardian
    (try! (as-contract (stx-transfer? reward-amount tx-sender guardian)))
    
    ;; Update guardian rewards record
    (map-set guardian-rewards
      { guardian: guardian }
      {
        total-earned: (+ (get total-earned current-rewards) reward-amount),
        last-reward: reward-amount,
        performance-score: (if (<= (+ (get performance-score current-rewards) performance-bonus) u100)
                            (+ (get performance-score current-rewards) performance-bonus)
                            u100),
        forests-saved: (+ (get forests-saved current-rewards) u1),
        carbon-credits-generated: (get carbon-credits-generated current-rewards)
      }
    )
    
    ;; Update vault balance
    (var-set total-vault-balance (- (var-get total-vault-balance) reward-amount))
    
    (ok true)
  )
)

;; Carbon Credit Management
(define-public (generate-carbon-credits
    (forest-token-id uint)
    (amount-tons uint)
    (price-per-ton uint)
  )
  (let (
    (credit-id (var-get total-carbon-credits-generated))
  )
    ;; Validate inputs
    (asserts! (> amount-tons u0) ERR_INVALID_AMOUNT)
    (asserts! (> price-per-ton u0) ERR_INVALID_AMOUNT)
    
    ;; Create carbon credit record
    (map-set carbon-credits
      { credit-id: credit-id }
      {
        forest-token-id: forest-token-id,
        owner: tx-sender,
        amount-tons: amount-tons,
        generated-date: stacks-block-height,
        verification-status: "pending",
        price-per-ton: price-per-ton
      }
    )
    
    ;; Update counter
    (var-set total-carbon-credits-generated (+ credit-id u1))
    
    (ok credit-id)
  )
)

;; Emergency Forest Protection
(define-public (emergency-protection-fund (forest-token-id uint) (required-funding uint))
  (begin
    ;; Only urgent cases (threat level >= 90)
    (asserts! (>= required-funding MIN_PROJECT_FUNDING) ERR_INVALID_AMOUNT)
    
    ;; Create emergency alert
    (map-set emergency-alerts
      { forest-token-id: forest-token-id }
      {
        alert-date: stacks-block-height,
        threat-level: u95, ;; Emergency level
        required-funding: required-funding,
        current-emergency-funding: u0,
        resolved: false
      }
    )
    
    (ok true)
  )
)

(define-public (contribute-emergency-fund (forest-token-id uint) (amount uint))
  (let (
    (alert (unwrap! (map-get? emergency-alerts { forest-token-id: forest-token-id }) ERR_NOT_FOUND))
  )
    ;; Check alert is not resolved
    (asserts! (not (get resolved alert)) ERR_NOT_FOUND)
    
    ;; Validate amount
    (asserts! (>= amount MIN_CONTRIBUTION) ERR_INVALID_AMOUNT)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update emergency funding
    (let (
      (new-emergency-funding (+ (get current-emergency-funding alert) amount))
    )
      (map-set emergency-alerts
        { forest-token-id: forest-token-id }
        (merge alert {
          current-emergency-funding: new-emergency-funding,
          resolved: (>= new-emergency-funding (get required-funding alert))
        })
      )
    )
    
    ;; Update emergency fund balance
    (var-set emergency-fund-balance (+ (var-get emergency-fund-balance) amount))
    
    (ok true)
  )
)

;; Impact Tracking
(define-public (update-forest-impact
    (forest-token-id uint)
    (hectares-protected uint)
    (co2-sequestered uint)
    (biodiversity-preserved uint)
    (community-jobs-created uint)
    (deforestation-prevented uint)
  )
  (begin
    ;; Update impact metrics
    (map-set forest-impact-metrics
      { forest-token-id: forest-token-id }
      {
        hectares-protected: hectares-protected,
        co2-sequestered: co2-sequestered,
        biodiversity-preserved: biodiversity-preserved,
        community-jobs-created: community-jobs-created,
        deforestation-prevented: deforestation-prevented,
        last-updated: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-conservation-project-info (project-id uint))
  (map-get? conservation-projects { project-id: project-id })
)

(define-read-only (get-contribution-info (project-id uint) (contributor principal))
  (map-get? project-contributions { project-id: project-id, contributor: contributor })
)

(define-read-only (get-guardian-rewards-info (guardian principal))
  (map-get? guardian-rewards { guardian: guardian })
)

(define-read-only (get-carbon-credit-info (credit-id uint))
  (map-get? carbon-credits { credit-id: credit-id })
)

(define-read-only (get-emergency-alert-info (forest-token-id uint))
  (map-get? emergency-alerts { forest-token-id: forest-token-id })
)

(define-read-only (get-forest-impact-metrics (forest-token-id uint))
  (map-get? forest-impact-metrics { forest-token-id: forest-token-id })
)

(define-read-only (get-total-vault-balance)
  (var-get total-vault-balance)
)

(define-read-only (get-total-conservation-projects)
  (var-get total-conservation-projects)
)

(define-read-only (get-total-funded-projects)
  (var-get total-funded-projects)
)

(define-read-only (get-total-carbon-credits-generated)
  (var-get total-carbon-credits-generated)
)

(define-read-only (get-emergency-fund-balance)
  (var-get emergency-fund-balance)
)

(define-read-only (calculate-conservation-impact (project-id uint))
  (match (map-get? conservation-projects { project-id: project-id })
    project (let (
      (funding-efficiency (/ (get current-funding project) (if (> (get funding-goal project) u0) (get funding-goal project) u1)))
      (expected-impact (* funding-efficiency (get expected-carbon-credits project)))
    )
      (some {
        funding-efficiency: funding-efficiency,
        expected-carbon-credits: expected-impact,
        biodiversity-impact: (* funding-efficiency (get biodiversity-targets project)),
        project-completion: (get completion-percentage project)
      })
    )
    none
  )
)

(define-read-only (get-project-funding-summary (project-id uint))
  (match (map-get? conservation-projects { project-id: project-id })
    project (some {
      current-funding: (get current-funding project),
      funding-goal: (get funding-goal project),
      completion-percentage: (get completion-percentage project),
      contributors-count: (get contributors-count project),
      days-remaining: (if (> (get deadline project) stacks-block-height)
                       (/ (- (get deadline project) stacks-block-height) u144)
                       u0),
      status: (get status project)
    })
    none
  )
)

;; title: conservation-vault
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;


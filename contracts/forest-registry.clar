;; ForestFi Forest Registry Contract
;; Manages forest zone NFTs, guardians, and conservation data

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))
(define-constant ERR_GUARDIAN_NOT_VERIFIED (err u104))
(define-constant ERR_TOKEN_NOT_FOUND (err u105))
(define-constant ERR_INVALID_COORDINATES (err u106))
(define-constant ERR_INVALID_ECOSYSTEM (err u107))
(define-constant ERR_TRANSFER_RESTRICTED (err u108))
(define-constant ERR_FOREST_COMPROMISED (err u109))

;; Ecosystem type constants
(define-constant ECOSYSTEM_TROPICAL "tropical-rainforest")
(define-constant ECOSYSTEM_TEMPERATE "temperate-forest")
(define-constant ECOSYSTEM_BOREAL "boreal-forest")
(define-constant ECOSYSTEM_MANGROVE "mangrove-forest")
(define-constant ECOSYSTEM_MOUNTAIN "mountain-forest")
(define-constant ECOSYSTEM_DRY "dry-forest")

;; Conservation status constants
(define-constant STATUS_SECURE "secure")
(define-constant STATUS_VULNERABLE "vulnerable")
(define-constant STATUS_ENDANGERED "endangered")
(define-constant STATUS_CRITICALLY_ENDANGERED "critical")
(define-constant STATUS_DESTROYED "destroyed")

;; Data Variables
(define-data-var next-token-id uint u1)
(define-data-var next-guardian-id uint u1)
(define-data-var total-forest-tokens uint u0)
(define-data-var total-verified-guardians uint u0)
(define-data-var total-protected-hectares uint u0)
(define-data-var total-carbon-storage uint u0)

;; NFT Definition
(define-non-fungible-token forest-nft uint)

;; Data Maps
(define-map forest-tokens
  { token-id: uint }
  {
    owner: principal,
    guardian: principal,
    forest-name: (string-utf8 100),
    location: (string-utf8 150),
    latitude: int,
    longitude: int,
    area-hectares: uint,
    ecosystem-type: (string-ascii 50),
    threat-level: uint,
    conservation-status: (string-ascii 30),
    biodiversity-score: uint,
    carbon-storage: uint,
    protection-start: uint,
    last-verified: uint,
    metadata-uri: (string-utf8 200),
    mint-timestamp: uint
  }
)

(define-map forest-guardians
  { guardian-id: uint }
  {
    address: principal,
    name: (string-utf8 100),
    organization: (string-utf8 100),
    location-region: (string-utf8 100),
    contact-info: (string-utf8 200),
    verified: bool,
    reputation-score: uint,
    forests-protected: uint,
    total-area-hectares: uint,
    registration-date: uint,
    last-activity: uint
  }
)

(define-map guardian-by-address
  { address: principal }
  { guardian-id: uint }
)

(define-map forest-monitoring
  { token-id: uint, report-id: uint }
  {
    reporter: principal,
    report-date: uint,
    threat-level: uint,
    deforestation-detected: bool,
    conservation-actions: (string-utf8 300),
    verified: bool
  }
)

(define-map ecosystem-stats
  { ecosystem-type: (string-ascii 50) }
  {
    total-tokens: uint,
    total-hectares: uint,
    average-threat-level: uint,
    total-carbon-storage: uint
  }
)

;; Guardian Management Functions
(define-public (register-guardian
    (name (string-utf8 100))
    (organization (string-utf8 100))
    (location-region (string-utf8 100))
    (contact-info (string-utf8 200))
  )
  (let (
    (guardian-id (var-get next-guardian-id))
  )
    ;; Validate inputs
    (asserts! (> (len name) u0) ERR_INVALID_PARAMS)
    (asserts! (> (len organization) u0) ERR_INVALID_PARAMS)
    
    ;; Check if guardian already exists
    (asserts! (is-none (map-get? guardian-by-address { address: tx-sender })) ERR_ALREADY_EXISTS)
    
    ;; Create guardian record
    (map-set forest-guardians
      { guardian-id: guardian-id }
      {
        address: tx-sender,
        name: name,
        organization: organization,
        location-region: location-region,
        contact-info: contact-info,
        verified: false,
        reputation-score: u50,
        forests-protected: u0,
        total-area-hectares: u0,
        registration-date: stacks-block-height,
        last-activity: stacks-block-height
      }
    )
    
    ;; Map address to guardian ID
    (map-set guardian-by-address
      { address: tx-sender }
      { guardian-id: guardian-id }
    )
    
    ;; Update counters
    (var-set next-guardian-id (+ guardian-id u1))
    
    (ok guardian-id)
  )
)

(define-public (verify-guardian (guardian-id uint))
  (let (
    (guardian (unwrap! (map-get? forest-guardians { guardian-id: guardian-id }) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (map-set forest-guardians
      { guardian-id: guardian-id }
      (merge guardian { 
        verified: true, 
        reputation-score: u75 
      })
    )
    
    (var-set total-verified-guardians (+ (var-get total-verified-guardians) u1))
    (ok true)
  )
)

;; Forest NFT Functions
(define-public (mint-forest-nft
    (forest-name (string-utf8 100))
    (location (string-utf8 150))
    (latitude int)
    (longitude int)
    (area-hectares uint)
    (ecosystem-type (string-ascii 50))
    (threat-level uint)
    (conservation-status (string-ascii 30))
    (biodiversity-score uint)
    (carbon-storage uint)
    (metadata-uri (string-utf8 200))
  )
  (let (
    (token-id (var-get next-token-id))
    (guardian-info (unwrap! (map-get? guardian-by-address { address: tx-sender }) ERR_NOT_AUTHORIZED))
    (guardian (unwrap! (map-get? forest-guardians { guardian-id: (get guardian-id guardian-info) }) ERR_NOT_FOUND))
  )
    ;; Validate ecosystem type
    (asserts! (or
      (is-eq ecosystem-type ECOSYSTEM_TROPICAL)
      (is-eq ecosystem-type ECOSYSTEM_TEMPERATE)
      (is-eq ecosystem-type ECOSYSTEM_BOREAL)
      (is-eq ecosystem-type ECOSYSTEM_MANGROVE)
      (is-eq ecosystem-type ECOSYSTEM_MOUNTAIN)
      (is-eq ecosystem-type ECOSYSTEM_DRY)
    ) ERR_INVALID_ECOSYSTEM)
    
    ;; Only verified guardians can mint forest NFTs
    (asserts! (get verified guardian) ERR_GUARDIAN_NOT_VERIFIED)
    
    ;; Validate coordinates and metrics
    (asserts! (and (>= latitude -900000) (<= latitude 900000)) ERR_INVALID_COORDINATES) ;; -90 to 90 degrees * 10000
    (asserts! (and (>= longitude -1800000) (<= longitude 1800000)) ERR_INVALID_COORDINATES) ;; -180 to 180 degrees * 10000
    (asserts! (> area-hectares u0) ERR_INVALID_PARAMS)
    (asserts! (and (>= threat-level u1) (<= threat-level u100)) ERR_INVALID_PARAMS)
    (asserts! (and (>= biodiversity-score u1) (<= biodiversity-score u100)) ERR_INVALID_PARAMS)
    
    ;; Mint NFT to guardian
    (try! (nft-mint? forest-nft token-id tx-sender))
    
    ;; Store forest token data
    (map-set forest-tokens
      { token-id: token-id }
      {
        owner: tx-sender,
        guardian: tx-sender,
        forest-name: forest-name,
        location: location,
        latitude: latitude,
        longitude: longitude,
        area-hectares: area-hectares,
        ecosystem-type: ecosystem-type,
        threat-level: threat-level,
        conservation-status: conservation-status,
        biodiversity-score: biodiversity-score,
        carbon-storage: carbon-storage,
        protection-start: stacks-block-height,
        last-verified: stacks-block-height,
        metadata-uri: metadata-uri,
        mint-timestamp: stacks-block-height
      }
    )
    
    ;; Update guardian stats
    (map-set forest-guardians
      { guardian-id: (get guardian-id guardian-info) }
      (merge guardian {
        forests-protected: (+ (get forests-protected guardian) u1),
        total-area-hectares: (+ (get total-area-hectares guardian) area-hectares),
        reputation-score: (if (<= (+ (get reputation-score guardian) u2) u100) 
                           (+ (get reputation-score guardian) u2) 
                           u100),
        last-activity: stacks-block-height
      })
    )
    
    ;; Update ecosystem stats
    (let (
      (current-stats (default-to 
        { total-tokens: u0, total-hectares: u0, average-threat-level: u0, total-carbon-storage: u0 }
        (map-get? ecosystem-stats { ecosystem-type: ecosystem-type })
      ))
    )
      (map-set ecosystem-stats
        { ecosystem-type: ecosystem-type }
        {
          total-tokens: (+ (get total-tokens current-stats) u1),
          total-hectares: (+ (get total-hectares current-stats) area-hectares),
          average-threat-level: (/ (+ (* (get average-threat-level current-stats) (get total-tokens current-stats)) threat-level)
                                  (+ (get total-tokens current-stats) u1)),
          total-carbon-storage: (+ (get total-carbon-storage current-stats) carbon-storage)
        }
      )
    )
    
    ;; Update global counters
    (var-set next-token-id (+ token-id u1))
    (var-set total-forest-tokens (+ (var-get total-forest-tokens) u1))
    (var-set total-protected-hectares (+ (var-get total-protected-hectares) area-hectares))
    (var-set total-carbon-storage (+ (var-get total-carbon-storage) carbon-storage))
    
    (ok token-id)
  )
)

(define-public (transfer-forest-ownership (token-id uint) (recipient principal) (transfer-reason (string-utf8 200)))
  (let (
    (token-info (unwrap! (map-get? forest-tokens { token-id: token-id }) ERR_TOKEN_NOT_FOUND))
    (current-owner (unwrap! (nft-get-owner? forest-nft token-id) ERR_TOKEN_NOT_FOUND))
  )
    ;; Only current owner can transfer
    (asserts! (is-eq tx-sender current-owner) ERR_NOT_AUTHORIZED)
    
    ;; Check forest is not in critical state
    (asserts! (not (is-eq (get conservation-status token-info) STATUS_DESTROYED)) ERR_FOREST_COMPROMISED)
    (asserts! (< (get threat-level token-info) u90) ERR_FOREST_COMPROMISED)
    
    ;; Transfer NFT
    (try! (nft-transfer? forest-nft token-id current-owner recipient))
    
    ;; Update token owner
    (map-set forest-tokens
      { token-id: token-id }
      (merge token-info { owner: recipient })
    )
    
    (ok true)
  )
)

(define-public (update-forest-status (token-id uint) (new-threat-level uint) (new-status (string-ascii 30)) (conservation-actions (string-utf8 300)))
  (let (
    (token-info (unwrap! (map-get? forest-tokens { token-id: token-id }) ERR_TOKEN_NOT_FOUND))
  )
    ;; Only guardian can update forest status
    (asserts! (is-eq tx-sender (get guardian token-info)) ERR_NOT_AUTHORIZED)
    
    ;; Validate threat level
    (asserts! (and (>= new-threat-level u1) (<= new-threat-level u100)) ERR_INVALID_PARAMS)
    
    ;; Update forest status
    (map-set forest-tokens
      { token-id: token-id }
      (merge token-info {
        threat-level: new-threat-level,
        conservation-status: new-status,
        last-verified: stacks-block-height
      })
    )
    
    ;; Record monitoring report (simplified - would need report counter)
    (map-set forest-monitoring
      { token-id: token-id, report-id: u1 }
      {
        reporter: tx-sender,
        report-date: stacks-block-height,
        threat-level: new-threat-level,
        deforestation-detected: (> new-threat-level u80),
        conservation-actions: conservation-actions,
        verified: true
      }
    )
    
    (ok true)
  )
)

(define-public (emergency-forest-alert (token-id uint) (alert-message (string-utf8 300)))
  (let (
    (token-info (unwrap! (map-get? forest-tokens { token-id: token-id }) ERR_TOKEN_NOT_FOUND))
  )
    ;; Only guardian or owner can create emergency alert
    (asserts! (or 
      (is-eq tx-sender (get guardian token-info))
      (is-eq tx-sender (get owner token-info))
    ) ERR_NOT_AUTHORIZED)
    
    ;; Update to critical threat level
    (map-set forest-tokens
      { token-id: token-id }
      (merge token-info {
        threat-level: u95,
        conservation-status: STATUS_CRITICALLY_ENDANGERED,
        last-verified: stacks-block-height
      })
    )
    
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-forest-info (token-id uint))
  (map-get? forest-tokens { token-id: token-id })
)

(define-read-only (get-guardian-info (guardian-id uint))
  (map-get? forest-guardians { guardian-id: guardian-id })
)

(define-read-only (get-guardian-by-address (address principal))
  (match (map-get? guardian-by-address { address: address })
    guardian-info (map-get? forest-guardians { guardian-id: (get guardian-id guardian-info) })
    none
  )
)

(define-read-only (get-ecosystem-stats (ecosystem-type (string-ascii 50)))
  (map-get? ecosystem-stats { ecosystem-type: ecosystem-type })
)

(define-read-only (get-forest-owner (token-id uint))
  (nft-get-owner? forest-nft token-id)
)

(define-read-only (get-total-forest-tokens)
  (var-get total-forest-tokens)
)

(define-read-only (get-total-verified-guardians)
  (var-get total-verified-guardians)
)

(define-read-only (get-total-protected-hectares)
  (var-get total-protected-hectares)
)

(define-read-only (get-total-carbon-storage)
  (var-get total-carbon-storage)
)

(define-read-only (is-valid-ecosystem (ecosystem-type (string-ascii 50)))
  (or
    (is-eq ecosystem-type ECOSYSTEM_TROPICAL)
    (is-eq ecosystem-type ECOSYSTEM_TEMPERATE)
    (is-eq ecosystem-type ECOSYSTEM_BOREAL)
    (is-eq ecosystem-type ECOSYSTEM_MANGROVE)
    (is-eq ecosystem-type ECOSYSTEM_MOUNTAIN)
    (is-eq ecosystem-type ECOSYSTEM_DRY)
  )
)

(define-read-only (calculate-conservation-priority (token-id uint))
  (match (map-get? forest-tokens { token-id: token-id })
    forest-info (let (
      (threat-weight (* (get threat-level forest-info) u3))
      (biodiversity-weight (* (get biodiversity-score forest-info) u2))
      (carbon-weight (/ (get carbon-storage forest-info) u100))
      (area-weight (/ (get area-hectares forest-info) u10))
    )
      (/ (+ threat-weight biodiversity-weight carbon-weight area-weight) u6)
    )
    u0
  )
)

(define-read-only (get-forest-monitoring-report (token-id uint) (report-id uint))
  (map-get? forest-monitoring { token-id: token-id, report-id: report-id })
)

;; SIP-009 NFT Standard Functions
(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1))
)

(define-read-only (get-token-uri (token-id uint))
  (match (map-get? forest-tokens { token-id: token-id })
    token-info (ok (some (get metadata-uri token-info)))
    (ok none)
  )
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? forest-nft token-id))
)

;; title: forest-registry
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


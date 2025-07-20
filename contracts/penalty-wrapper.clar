;; penalty-wrapper
;; 
;; A smart contract for managing asset penalties and compliance mechanisms
;; within a tokenized asset ecosystem.

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ASSET-PENALTY-EXISTS (err u201))
(define-constant ERR-ASSET-PENALTY-NOT-FOUND (err u202))
(define-constant ERR-PENALTY-ALREADY-RESOLVED (err u203))
(define-constant ERR-INVALID-PENALTY-AMOUNT (err u204))

;; Contract Owner
(define-constant CONTRACT-OWNER tx-sender)

;; Penalty Status
(define-constant STATUS-PENDING u1)
(define-constant STATUS-RESOLVED u2)
(define-constant STATUS-DISPUTED u3)

;; Data Structures

;; Tracks penalties for assets
(define-map asset-penalties
  { 
    asset-id: (string-ascii 36),
    penalty-id: (string-ascii 36)
  }
  {
    issuer: principal,
    amount: uint,
    reason: (string-utf8 256),
    status: uint,
    created-at: uint,
    resolved-at: (optional uint)
  }
)

;; Tracks penalty resolution history
(define-map penalty-resolutions
  {
    asset-id: (string-ascii 36),
    penalty-id: (string-ascii 36)
  }
  {
    resolver: principal,
    resolution-type: (string-ascii 32),
    details: (string-utf8 256),
    resolved-at: uint
  }
)

;; Global Counters
(define-data-var total-penalties uint u0)

;; Private Helper Functions

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Check if penalty exists
(define-private (penalty-exists (asset-id (string-ascii 36)) (penalty-id (string-ascii 36)))
  (is-some (map-get? asset-penalties { asset-id: asset-id, penalty-id: penalty-id }))
)

;; Read-Only Functions

;; Get penalty details
(define-read-only (get-penalty-details (asset-id (string-ascii 36)) (penalty-id (string-ascii 36)))
  (if (penalty-exists asset-id penalty-id)
    (ok (map-get? asset-penalties { asset-id: asset-id, penalty-id: penalty-id }))
    ERR-ASSET-PENALTY-NOT-FOUND
  )
)

;; Public Functions

;; Issue a penalty against an asset
(define-public (issue-penalty
  (asset-id (string-ascii 36))
  (penalty-id (string-ascii 36))
  (amount uint)
  (reason (string-utf8 256))
)
  (begin
    (if (penalty-exists asset-id penalty-id)
      ERR-ASSET-PENALTY-EXISTS
      (begin
        (map-set asset-penalties
          { asset-id: asset-id, penalty-id: penalty-id }
          {
            issuer: tx-sender,
            amount: amount,
            reason: reason,
            status: STATUS-PENDING,
            created-at: block-height,
            resolved-at: none
          }
        )
        (var-set total-penalties (+ (var-get total-penalties) u1))
        (ok { 
          asset-id: asset-id, 
          penalty-id: penalty-id, 
          status: STATUS-PENDING 
        })
      )
    )
  )
)

;; Resolve a penalty
(define-public (resolve-penalty
  (asset-id (string-ascii 36))
  (penalty-id (string-ascii 36))
  (resolution-type (string-ascii 32))
  (details (string-utf8 256))
)
  (let ((penalty-data (map-get? asset-penalties { asset-id: asset-id, penalty-id: penalty-id })))
    (if (is-none penalty-data)
      ERR-ASSET-PENALTY-NOT-FOUND
      (let ((current-penalty (unwrap-panic penalty-data)))
        (if (is-eq (get status current-penalty) STATUS-RESOLVED)
          ERR-PENALTY-ALREADY-RESOLVED
          (begin
            (map-set asset-penalties
              { asset-id: asset-id, penalty-id: penalty-id }
              (merge current-penalty {
                status: STATUS-RESOLVED,
                resolved-at: (some block-height)
              })
            )
            
            (map-set penalty-resolutions
              { asset-id: asset-id, penalty-id: penalty-id }
              {
                resolver: tx-sender,
                resolution-type: resolution-type,
                details: details,
                resolved-at: block-height
              }
            )
            
            (ok { 
              asset-id: asset-id, 
              penalty-id: penalty-id, 
              resolved: true 
            })
          )
        )
      )
    )
  )
)

;; Administrative function to dispute a penalty
(define-public (dispute-penalty
  (asset-id (string-ascii 36))
  (penalty-id (string-ascii 36))
  (dispute-reason (string-utf8 256))
)
  (let ((penalty-data (map-get? asset-penalties { asset-id: asset-id, penalty-id: penalty-id })))
    (if (is-none penalty-data)
      ERR-ASSET-PENALTY-NOT-FOUND
      (if (not (is-contract-owner))
        ERR-NOT-AUTHORIZED
        (begin
          (map-set asset-penalties
            { asset-id: asset-id, penalty-id: penalty-id }
            (merge (unwrap-panic penalty-data) {
              status: STATUS-DISPUTED
            })
          )
          
          (ok { 
            asset-id: asset-id, 
            penalty-id: penalty-id, 
            disputed: true 
          })
        )
      )
    )
  )
)
;; ClarityDeed - A smart contract for tokenizing real estate assets
;; Enables secure blockchain-based ownership transfers with proper verification

;; Define the data storage for property deeds
(define-map property-deeds
  { property-id: (string-ascii 36) }
  {
    owner: principal,
    property-details: (string-utf8 500),
    valuation: uint,
    for-sale: bool,
    asking-price: uint,
    creation-block: uint,
    last-transfer-block: uint
  }
)

;; Map to track authorized notaries who can verify property transfers
(define-map authorized-notaries
  { notary: principal }
  { is-active: bool, jurisdiction: (string-ascii 50) }
)

;; Map to track pending transfers in escrow
(define-map escrow-transfers
  { property-id: (string-ascii 36) }
  {
    buyer: principal,
    seller: principal,
    price: uint,
    notary-approval: bool,
    buyer-approval: bool,
    seller-approval: bool,
    expiration-height: uint
  }
)

;; Define contract owner who can authorize notaries
(define-data-var contract-owner principal tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROPERTY-NOT-FOUND (err u101))
(define-constant ERR-PROPERTY-EXISTS (err u102))
(define-constant ERR-NOT-OWNER (err u103))
(define-constant ERR-NOT-FOR-SALE (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-TRANSFER-NOT-FOUND (err u106))
(define-constant ERR-TRANSFER-EXPIRED (err u107))
(define-constant ERR-ALREADY-AUTHORIZED (err u108))
(define-constant ERR-NOT-NOTARY (err u109))
(define-constant ERR-TRANSFER-INCOMPLETE (err u110))

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Function to register a new property deed
(define-public (register-property (property-id (string-ascii 36)) (property-details (string-utf8 500)) (valuation uint))
  (let ((existing-property (map-get? property-deeds { property-id: property-id })))
    (if (is-some existing-property)
      ERR-PROPERTY-EXISTS
      (begin
        (map-set property-deeds
          { property-id: property-id }
          {
            owner: tx-sender,
            property-details: property-details,
            valuation: valuation,
            for-sale: false,
            asking-price: u0,
            creation-block: block-height,
            last-transfer-block: block-height
          }
        )
        (ok true)
      )
    )
  )
)

;; Function to update property details (only by owner)
(define-public (update-property-details (property-id (string-ascii 36)) (property-details (string-utf8 500)) (valuation uint))
  (let ((property (map-get? property-deeds { property-id: property-id })))
    (if (is-none property)
      ERR-PROPERTY-NOT-FOUND
      (if (is-eq tx-sender (get owner (unwrap-panic property)))
        (begin
          (map-set property-deeds
            { property-id: property-id }
            (merge (unwrap-panic property) { property-details: property-details, valuation: valuation })
          )
          (ok true)
        )
        ERR-NOT-OWNER
      )
    )
  )
)

;; List property for sale
(define-public (list-property-for-sale (property-id (string-ascii 36)) (asking-price uint))
  (let ((property (map-get? property-deeds { property-id: property-id })))
    (if (is-none property)
      ERR-PROPERTY-NOT-FOUND
      (if (is-eq tx-sender (get owner (unwrap-panic property)))
        (begin
          (map-set property-deeds
            { property-id: property-id }
            (merge (unwrap-panic property) { for-sale: true, asking-price: asking-price })
          )
          (ok true)
        )
        ERR-NOT-OWNER
      )
    )
  )
)

;; Remove property from sale
(define-public (delist-property (property-id (string-ascii 36)))
  (let ((property (map-get? property-deeds { property-id: property-id })))
    (if (is-none property)
      ERR-PROPERTY-NOT-FOUND
      (if (is-eq tx-sender (get owner (unwrap-panic property)))
        (begin
          (map-set property-deeds
            { property-id: property-id }
            (merge (unwrap-panic property) { for-sale: false })
          )
          (ok true)
        )
        ERR-NOT-OWNER
      )
    )
  )
)

;; Initiate purchase (put funds in escrow)
(define-public (initiate-purchase (property-id (string-ascii 36)))
  (let (
    (property (map-get? property-deeds { property-id: property-id }))
    (existing-escrow (map-get? escrow-transfers { property-id: property-id }))
  )
    (if (is-none property)
      ERR-PROPERTY-NOT-FOUND
      (let ((property-data (unwrap-panic property)))
        (if (not (get for-sale property-data))
          ERR-NOT-FOR-SALE
          (if (is-some existing-escrow)
            (err u111) ;; Already has pending transfer
            (let ((price (get asking-price property-data)))
              (if (< (stx-get-balance tx-sender) price)
                ERR-INSUFFICIENT-FUNDS
                (begin
                  ;; Transfer STX to escrow (contract itself)
                  (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
                  
                  ;; Create escrow entry
                  (map-set escrow-transfers
                    { property-id: property-id }
                    {
                      buyer: tx-sender,
                      seller: (get owner property-data),
                      price: price,
                      notary-approval: false,
                      buyer-approval: true, ;; Buyer approves by initiating
                      seller-approval: false,
                      expiration-height: (+ block-height u1440) ;; ~10 days in blocks
                    }
                  )
                  (ok true)
                )
              )
            )
          )
        )
      )
    )
  )
)

;; Seller approves transfer
(define-public (approve-transfer-as-seller (property-id (string-ascii 36)))
  (let (
    (property (map-get? property-deeds { property-id: property-id }))
    (escrow (map-get? escrow-transfers { property-id: property-id }))
  )
    (if (or (is-none property) (is-none escrow))
      ERR-TRANSFER-NOT-FOUND
      (let (
        (property-data (unwrap-panic property))
        (escrow-data (unwrap-panic escrow))
      )
        (if (not (is-eq tx-sender (get owner property-data)))
          ERR-NOT-OWNER
          (if (> block-height (get expiration-height escrow-data))
            ERR-TRANSFER-EXPIRED
            (begin
              (map-set escrow-transfers
                { property-id: property-id }
                (merge escrow-data { seller-approval: true })
              )
              (ok true)
            )
          )
        )
      )
    )
  )
)

;; Notary approves transfer after verification
(define-public (approve-transfer-as-notary (property-id (string-ascii 36)))
  (let (
    (property (map-get? property-deeds { property-id: property-id }))
    (escrow (map-get? escrow-transfers { property-id: property-id }))
    (notary-status (map-get? authorized-notaries { notary: tx-sender }))
  )
    (if (is-none notary-status)
      ERR-NOT-NOTARY
      (if (not (get is-active (unwrap-panic notary-status)))
        ERR-NOT-AUTHORIZED
        (if (or (is-none property) (is-none escrow))
          ERR-TRANSFER-NOT-FOUND
          (let ((escrow-data (unwrap-panic escrow)))
            (if (> block-height (get expiration-height escrow-data))
              ERR-TRANSFER-EXPIRED
              (begin
                (map-set escrow-transfers
                  { property-id: property-id }
                  (merge escrow-data { notary-approval: true })
                )
                (ok true)
              )
            )
          )
        )
      )
    )
  )
)

;; Complete property transfer when all approvals are in place
(define-public (complete-transfer (property-id (string-ascii 36)))
  (let (
    (property (map-get? property-deeds { property-id: property-id }))
    (escrow (map-get? escrow-transfers { property-id: property-id }))
  )
    (if (or (is-none property) (is-none escrow))
      ERR-TRANSFER-NOT-FOUND
      (let (
        (property-data (unwrap-panic property))
        (escrow-data (unwrap-panic escrow))
      )
        (if (> block-height (get expiration-height escrow-data))
          ERR-TRANSFER-EXPIRED
          (if (and 
                (get seller-approval escrow-data)
                (get buyer-approval escrow-data)
                (get notary-approval escrow-data)
              )
            (begin
              ;; Transfer funds from escrow to seller
              (try! (as-contract (stx-transfer? (get price escrow-data) tx-sender (get seller escrow-data))))
              
              ;; Transfer property to buyer
              (map-set property-deeds
                { property-id: property-id }
                (merge property-data { 
                  owner: (get buyer escrow-data),
                  for-sale: false,
                  last-transfer-block: block-height
                })
              )
              
              ;; Clear the escrow
              (map-delete escrow-transfers { property-id: property-id })
              
              (ok true)
            )
            ERR-TRANSFER-INCOMPLETE
          )
        )
      )
    )
  )
)

;; Cancel transfer and refund - can be called by any party before completion
(define-public (cancel-transfer (property-id (string-ascii 36)))
  (let (
    (escrow (map-get? escrow-transfers { property-id: property-id }))
  )
    (if (is-none escrow)
      ERR-TRANSFER-NOT-FOUND
      (let ((escrow-data (unwrap-panic escrow)))
        (if (and 
              (not (is-eq tx-sender (get buyer escrow-data)))
              (not (is-eq tx-sender (get seller escrow-data)))
              (not (is-authorized-notary tx-sender))
            )
          ERR-NOT-AUTHORIZED
          (begin
            ;; Refund the buyer
            (try! (as-contract (stx-transfer? (get price escrow-data) tx-sender (get buyer escrow-data))))
            
            ;; Clear the escrow
            (map-delete escrow-transfers { property-id: property-id })
            
            (ok true)
          )
        )
      )
    )
  )
)

;; Auto-refund expired transfers - anyone can call
(define-public (refund-expired-transfer (property-id (string-ascii 36)))
  (let (
    (escrow (map-get? escrow-transfers { property-id: property-id }))
  )
    (if (is-none escrow)
      ERR-TRANSFER-NOT-FOUND
      (let ((escrow-data (unwrap-panic escrow)))
        (if (<= block-height (get expiration-height escrow-data))
          (err u112) ;; Not expired yet
          (begin
            ;; Refund the buyer
            (try! (as-contract (stx-transfer? (get price escrow-data) tx-sender (get buyer escrow-data))))
            
            ;; Clear the escrow
            (map-delete escrow-transfers { property-id: property-id })
            
            (ok true)
          )
        )
      )
    )
  )
)

;; Add a notary (only contract owner)
(define-public (add-notary (notary principal) (jurisdiction (string-ascii 50)))
  (if (not (is-contract-owner))
    ERR-NOT-AUTHORIZED
    (let ((existing-notary (map-get? authorized-notaries { notary: notary })))
      (if (is-some existing-notary)
        ERR-ALREADY-AUTHORIZED
        (begin
          (map-set authorized-notaries
            { notary: notary }
            { is-active: true, jurisdiction: jurisdiction }
          )
          (ok true)
        )
      )
    )
  )
)

;; Deactivate a notary (only contract owner)
(define-public (deactivate-notary (notary principal))
  (if (not (is-contract-owner))
    ERR-NOT-AUTHORIZED
    (let ((existing-notary (map-get? authorized-notaries { notary: notary })))
      (if (is-none existing-notary)
        ERR-NOT-NOTARY
        (begin
          (map-set authorized-notaries
            { notary: notary }
            (merge (unwrap-panic existing-notary) { is-active: false })
          )
          (ok true)
        )
      )
    )
  )
)

;; Helper to check if sender is authorized notary
(define-private (is-authorized-notary (user principal))
  (let ((notary-status (map-get? authorized-notaries { notary: user })))
    (and (is-some notary-status) (get is-active (unwrap-panic notary-status)))
  )
)

;; Transfer contract ownership (only current owner)
(define-public (transfer-contract-ownership (new-owner principal))
  (if (not (is-contract-owner))
    ERR-NOT-AUTHORIZED
    (begin
      (var-set contract-owner new-owner)
      (ok true)
    )
  )
)

;; Read-only functions for querying the contract state

;; Get property details
(define-read-only (get-property (property-id (string-ascii 36)))
  (map-get? property-deeds { property-id: property-id })
)

;; Check if address is the property owner
(define-read-only (is-property-owner (property-id (string-ascii 36)) (address principal))
  (let ((property (map-get? property-deeds { property-id: property-id })))
    (if (is-none property)
      false
      (is-eq address (get owner (unwrap-panic property)))
    )
  )
)

;; Get escrow details
(define-read-only (get-escrow-details (property-id (string-ascii 36)))
  (map-get? escrow-transfers { property-id: property-id })
)

;; Check if address is an authorized notary
(define-read-only (is-notary-active (address principal))
  (let ((notary-data (map-get? authorized-notaries { notary: address })))
    (if (is-none notary-data)
      false
      (get is-active (unwrap-panic notary-data))
    )
  )
)

;; Get notary details
(define-read-only (get-notary-details (address principal))
  (map-get? authorized-notaries { notary: address })
)
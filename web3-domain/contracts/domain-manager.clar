;; Domain Name Service Contract
;; Manages domain registration, ownership, and transfers

;; Error codes
(define-constant ERROR-DOMAIN-ALREADY-REGISTERED (err u100))
(define-constant ERROR-NOT-AUTHORIZED (err u101))
(define-constant ERROR-DOMAIN-NOT-REGISTERED (err u102))
(define-constant ERROR-INVALID-DOMAIN-NAME (err u103))
(define-constant ERROR-DOMAIN-EXPIRED (err u104))
(define-constant ERROR-INSUFFICIENT-PAYMENT (err u105))

;; Configuration Constants
(define-constant DOMAIN-REGISTRATION-PERIOD-BLOCKS u52560) ;; ~1 year in blocks
(define-constant MINIMUM-DOMAIN-NAME-LENGTH u3)
(define-constant MAXIMUM-DOMAIN-NAME-LENGTH u63)
(define-constant DOMAIN-REGISTRATION-FEE-STX u100000) ;; in microSTX

;; Data Maps
(define-map domain-registry
    {domain-name: (string-ascii 64)}
    {
        domain-owner: principal,
        domain-expiration-block: uint,
        domain-resolver: (optional principal),
        domain-registration-block: uint,
        domain-name-hash: (buff 32)
    }
)

(define-map domain-preorder-registry
    {domain-name-hash: (buff 32)}
    {
        preorder-owner: principal,
        preorder-payment-amount: uint,
        preorder-block-height: uint
    }
)

(define-map domain-records
    {domain-name: (string-ascii 64), record-key: (string-ascii 128)}
    {record-value: (string-ascii 256)}
)

;; Public functions

;; Preorder a domain (hash commitment)
(define-public (preorder-domain (hashed-domain-name (buff 32)) (payment-amount-ustx uint))
    (let
        (
            (preorder-entry {
                preorder-owner: tx-sender,
                preorder-payment-amount: payment-amount-ustx,
                preorder-block-height: block-height
            })
        )
        (asserts! (>= payment-amount-ustx DOMAIN-REGISTRATION-FEE-STX) ERROR-INSUFFICIENT-PAYMENT)
        (try! (stx-burn? payment-amount-ustx tx-sender))
        (ok (map-set domain-preorder-registry {domain-name-hash: hashed-domain-name} preorder-entry))
    )
)

;; Register a domain name
(define-public (register-domain (domain-name (string-ascii 64)) (preorder-salt (buff 32)))
    (let
        (
            (calculated-name-hash (hash160 (concat (to-buff domain-name) preorder-salt)))
            (preorder-details (unwrap! (map-get? domain-preorder-registry {domain-name-hash: calculated-name-hash}) ERROR-DOMAIN-NOT-REGISTERED))
            (new-domain-entry {
                domain-owner: tx-sender,
                domain-expiration-block: (+ block-height DOMAIN-REGISTRATION-PERIOD-BLOCKS),
                domain-resolver: none,
                domain-registration-block: block-height,
                domain-name-hash: calculated-name-hash
            })
        )
        (asserts! (is-none (map-get? domain-registry {domain-name: domain-name})) ERROR-DOMAIN-ALREADY-REGISTERED)
        (asserts! (>= (len domain-name) MINIMUM-DOMAIN-NAME-LENGTH) ERROR-INVALID-DOMAIN-NAME)
        (asserts! (<= (len domain-name) MAXIMUM-DOMAIN-NAME-LENGTH) ERROR-INVALID-DOMAIN-NAME)
        (asserts! (is-eq tx-sender (get preorder-owner preorder-details)) ERROR-NOT-AUTHORIZED)
        
        (map-delete domain-preorder-registry {domain-name-hash: calculated-name-hash})
        (ok (map-set domain-registry {domain-name: domain-name} new-domain-entry))
    )
)

;; Transfer domain ownership
(define-public (transfer-domain (domain-name (string-ascii 64)) (new-domain-owner principal))
    (let
        (
            (current-domain-details (unwrap! (map-get? domain-registry {domain-name: domain-name}) ERROR-DOMAIN-NOT-REGISTERED))
        )
        (asserts! (is-eq tx-sender (get domain-owner current-domain-details)) ERROR-NOT-AUTHORIZED)
        (asserts! (< block-height (get domain-expiration-block current-domain-details)) ERROR-DOMAIN-EXPIRED)
        
        (ok (map-set domain-registry 
            {domain-name: domain-name}
            (merge current-domain-details {domain-owner: new-domain-owner})
        ))
    )
)

;; Renew domain registration
(define-public (renew-domain-registration (domain-name (string-ascii 64)))
    (let
        (
            (current-domain-details (unwrap! (map-get? domain-registry {domain-name: domain-name}) ERROR-DOMAIN-NOT-REGISTERED))
        )
        (asserts! (is-eq tx-sender (get domain-owner current-domain-details)) ERROR-NOT-AUTHORIZED)
        (try! (stx-burn? DOMAIN-REGISTRATION-FEE-STX tx-sender))
        
        (ok (map-set domain-registry
            {domain-name: domain-name}
            (merge current-domain-details {
                domain-expiration-block: (+ (get domain-expiration-block current-domain-details) DOMAIN-REGISTRATION-PERIOD-BLOCKS)
            })
        ))
    )
)

;; Set resolver for domain
(define-public (set-domain-resolver (domain-name (string-ascii 64)) (new-resolver (optional principal)))
    (let
        (
            (current-domain-details (unwrap! (map-get? domain-registry {domain-name: domain-name}) ERROR-DOMAIN-NOT-REGISTERED))
        )
        (asserts! (is-eq tx-sender (get domain-owner current-domain-details)) ERROR-NOT-AUTHORIZED)
        (asserts! (< block-height (get domain-expiration-block current-domain-details)) ERROR-DOMAIN-EXPIRED)
        
        (ok (map-set domain-registry
            {domain-name: domain-name}
            (merge current-domain-details {domain-resolver: new-resolver})
        ))
    )
)

;; Set domain records
(define-public (set-domain-record (domain-name (string-ascii 64)) (record-key (string-ascii 128)) (record-value (string-ascii 256)))
    (let
        (
            (current-domain-details (unwrap! (map-get? domain-registry {domain-name: domain-name}) ERROR-DOMAIN-NOT-REGISTERED))
        )
        (asserts! (is-eq tx-sender (get domain-owner current-domain-details)) ERROR-NOT-AUTHORIZED)
        (asserts! (< block-height (get domain-expiration-block current-domain-details)) ERROR-DOMAIN-EXPIRED)
        
        (ok (map-set domain-records
            {domain-name: domain-name, record-key: record-key}
            {record-value: record-value}
        ))
    )
)

;; Read-only functions

;; Get domain details
(define-read-only (get-domain-details (domain-name (string-ascii 64)))
    (map-get? domain-registry {domain-name: domain-name})
)

;; Get domain record
(define-read-only (get-domain-record (domain-name (string-ascii 64)) (record-key (string-ascii 128)))
    (map-get? domain-records {domain-name: domain-name, record-key: record-key})
)

;; Check domain availability
(define-read-only (is-domain-name-available (domain-name (string-ascii 64)))
    (is-none (map-get? domain-registry {domain-name: domain-name}))
)

;; Get domain expiration
(define-read-only (get-domain-expiration (domain-name (string-ascii 64)))
    (match (map-get? domain-registry {domain-name: domain-name})
        domain-details (ok (get domain-expiration-block domain-details))
        ERROR-DOMAIN-NOT-REGISTERED
    )
)

;; Private functions

;; Validate domain name
(define-private (is-valid-domain-name (domain-name (string-ascii 64)))
    (and
        (>= (len domain-name) MINIMUM-DOMAIN-NAME-LENGTH)
        (<= (len domain-name) MAXIMUM-DOMAIN-NAME-LENGTH)
    )
)
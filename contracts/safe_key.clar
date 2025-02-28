;; SafeKey - Decentralized Key Management System

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-KEY-NOT-FOUND (err u101)) 
(define-constant ERR-ALREADY-REGISTERED (err u102))
(define-constant ERR-PERMISSION-NOT-FOUND (err u103))
(define-constant ERR-KEY-INACTIVE (err u104))
(define-constant ERR-RATE-LIMITED (err u105))
(define-constant ERR-KEY-EXPIRED (err u106))

;; Data Variables
(define-map keys
    { key-id: uint }
    {
        owner: principal,
        active: bool,
        last-used: uint,
        expires-at: uint,
        use-count: uint,
        permissions: (list 10 principal)
    }
)

(define-map key-history
    { key-id: uint, timestamp: uint }
    { 
        action: (string-ascii 20),
        actor: principal
    }
)

(define-data-var key-counter uint u0)
(define-data-var rate-limit uint u100)

;; Private Functions
(define-private (is-owner (key-id uint) (caller principal))
    (let ((key-info (unwrap! (map-get? keys {key-id: key-id}) false)))
        (is-eq (get owner key-info) caller)
    )
)

(define-private (has-permission (key-id uint) (caller principal))
    (let ((key-info (unwrap! (map-get? keys {key-id: key-id}) false)))
        (and
            (get active key-info)
            (< block-height (get expires-at key-info))
            (or
                (is-eq (get owner key-info) caller)
                (is-some (index-of (get permissions key-info) caller))
            )
        )
    )
)

;; Public Functions
(define-public (register-key (expiry uint))
    (let 
        (
            (key-id (+ (var-get key-counter) u1))
        )
        (map-set keys
            {key-id: key-id}
            {
                owner: tx-sender,
                active: true,
                last-used: block-height,
                expires-at: (+ block-height expiry),
                use-count: u0,
                permissions: (list)
            }
        )
        (var-set key-counter key-id)
        (map-set key-history
            {key-id: key-id, timestamp: block-height}
            {action: "registered", actor: tx-sender}
        )
        (ok key-id)
    )
)

(define-public (set-key-status (key-id uint) (active bool))
    (if (is-owner key-id tx-sender)
        (let ((key-info (unwrap! (map-get? keys {key-id: key-id}) ERR-KEY-NOT-FOUND)))
            (map-set keys
                {key-id: key-id}
                (merge key-info {active: active})
            )
            (map-set key-history
                {key-id: key-id, timestamp: block-height}
                {action: (if active "activated" "deactivated"), actor: tx-sender}
            )
            (ok true)
        )
        ERR-NOT-AUTHORIZED
    )
)

;; [Previous functions remain unchanged: transfer-key, add-permission, remove-permission]

(define-public (use-key (key-id uint))
    (let ((key-info (unwrap! (map-get? keys {key-id: key-id}) ERR-KEY-NOT-FOUND)))
        (asserts! (has-permission key-id tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (get active key-info) ERR-KEY-INACTIVE)
        (asserts! (< block-height (get expires-at key-info)) ERR-KEY-EXPIRED)
        (asserts! (< (get use-count key-info) (var-get rate-limit)) ERR-RATE-LIMITED)
        
        (map-set keys
            {key-id: key-id}
            (merge key-info {
                last-used: block-height,
                use-count: (+ (get use-count key-info) u1)
            })
        )
        (map-set key-history
            {key-id: key-id, timestamp: block-height}
            {action: "used", actor: tx-sender}
        )
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-key-info (key-id uint))
    (map-get? keys {key-id: key-id})
)

(define-read-only (get-key-history-range (key-id uint) (start uint) (end uint))
    (map-get? key-history {key-id: key-id, timestamp: start})
)

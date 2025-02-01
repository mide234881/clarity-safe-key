;; SafeKey - Decentralized Key Management System

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-KEY-NOT-FOUND (err u101)) 
(define-constant ERR-ALREADY-REGISTERED (err u102))
(define-constant ERR-PERMISSION-NOT-FOUND (err u103))

;; Data Variables
(define-map keys
    { key-id: uint }
    {
        owner: principal,
        active: bool,
        last-used: uint,
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

;; Private Functions
(define-private (is-owner (key-id uint) (caller principal))
    (let ((key-info (unwrap! (map-get? keys {key-id: key-id}) false)))
        (is-eq (get owner key-info) caller)
    )
)

(define-private (has-permission (key-id uint) (caller principal))
    (let ((key-info (unwrap! (map-get? keys {key-id: key-id}) false)))
        (or
            (is-eq (get owner key-info) caller)
            (is-some (index-of (get permissions key-info) caller))
        )
    )
)

;; Public Functions
(define-public (register-key)
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

(define-public (transfer-key (key-id uint) (new-owner principal))
    (if (is-owner key-id tx-sender)
        (begin
            (map-set keys
                {key-id: key-id}
                {
                    owner: new-owner,
                    active: true,
                    last-used: block-height,
                    permissions: (list)
                }
            )
            (map-set key-history
                {key-id: key-id, timestamp: block-height}
                {action: "transferred", actor: tx-sender}
            )
            (ok true)
        )
        ERR-NOT-AUTHORIZED
    )
)

(define-public (add-permission (key-id uint) (user principal))
    (if (is-owner key-id tx-sender)
        (let ((key-info (unwrap! (map-get? keys {key-id: key-id}) ERR-KEY-NOT-FOUND)))
            (map-set keys
                {key-id: key-id}
                (merge key-info {
                    permissions: (unwrap! (as-max-len? (append (get permissions key-info) user) u10) ERR-NOT-AUTHORIZED)
                })
            )
            (map-set key-history
                {key-id: key-id, timestamp: block-height}
                {action: "permission-added", actor: tx-sender}
            )
            (ok true)
        )
        ERR-NOT-AUTHORIZED
    )
)

(define-public (remove-permission (key-id uint) (user principal))
    (if (is-owner key-id tx-sender)
        (let 
            (
                (key-info (unwrap! (map-get? keys {key-id: key-id}) ERR-KEY-NOT-FOUND))
                (permissions (get permissions key-info))
                (user-index (unwrap! (index-of permissions user) ERR-PERMISSION-NOT-FOUND))
            )
            (map-set keys
                {key-id: key-id}
                (merge key-info {
                    permissions: (concat (slice permissions u0 user-index) 
                                      (slice permissions (+ u1 user-index) (len permissions)))
                })
            )
            (map-set key-history
                {key-id: key-id, timestamp: block-height}
                {action: "permission-removed", actor: tx-sender}
            )
            (ok true)
        )
        ERR-NOT-AUTHORIZED
    )
)

(define-public (use-key (key-id uint))
    (if (has-permission key-id tx-sender)
        (begin
            (map-set key-history
                {key-id: key-id, timestamp: block-height}
                {action: "used", actor: tx-sender}
            )
            (ok true)
        )
        ERR-NOT-AUTHORIZED
    )
)

;; Read-only Functions
(define-read-only (get-key-info (key-id uint))
    (map-get? keys {key-id: key-id})
)

(define-read-only (get-key-history (key-id uint) (timestamp uint))
    (map-get? key-history {key-id: key-id, timestamp: timestamp})
)

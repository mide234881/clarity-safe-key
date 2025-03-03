;; SafeKey - Decentralized Key Management System

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-KEY-NOT-FOUND (err u101)) 
(define-constant ERR-ALREADY-REGISTERED (err u102))
(define-constant ERR-PERMISSION-NOT-FOUND (err u103))
(define-constant ERR-KEY-INACTIVE (err u104))
(define-constant ERR-RATE-LIMITED (err u105))
(define-constant ERR-KEY-EXPIRED (err u106))
(define-constant ERR-SYSTEM-PAUSED (err u107))

;; Data Variables
(define-data-var contract-paused bool false)
(define-data-var admin principal tx-sender)

(define-map keys
    { key-id: uint }
    {
        owner: principal,
        active: bool,
        last-used: uint,
        expires-at: uint,
        use-count: uint,
        permissions: (list 10 principal),
        usage-pattern: (list 5 uint),
        recovery-address: (optional principal)
    }
)

(define-map key-analytics
    { key-id: uint }
    {
        daily-uses: uint,
        last-reset: uint,
        peak-usage: uint
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

;; Administrative Functions
(define-public (set-contract-pause (paused bool))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
        (ok (var-set contract-paused paused))
    )
)

;; Enhanced Private Functions
(define-private (is-owner (key-id uint) (caller principal))
    (let ((key-info (unwrap! (map-get? keys {key-id: key-id}) false)))
        (is-eq (get owner key-info) caller)
    )
)

(define-private (update-analytics (key-id uint))
    (let (
        (current-analytics (default-to 
            {daily-uses: u0, last-reset: block-height, peak-usage: u0}
            (map-get? key-analytics {key-id: key-id})
        ))
        (daily-uses (+ (get daily-uses current-analytics) u1))
    )
    (map-set key-analytics
        {key-id: key-id}
        (merge current-analytics {
            daily-uses: daily-uses,
            peak-usage: (if (> daily-uses (get peak-usage current-analytics))
                daily-uses
                (get peak-usage current-analytics)
            )
        })
    )
    )
)

;; Enhanced Public Functions
(define-public (register-key (expiry uint) (recovery-address (optional principal)))
    (begin
        (asserts! (not (var-get contract-paused)) ERR-SYSTEM-PAUSED)
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
                    permissions: (list),
                    usage-pattern: (list),
                    recovery-address: recovery-address
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
)

;; [Previous functions remain with added pause check]

(define-public (use-key (key-id uint))
    (begin
        (asserts! (not (var-get contract-paused)) ERR-SYSTEM-PAUSED)
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
            (update-analytics key-id)
            (map-set key-history
                {key-id: key-id, timestamp: block-height}
                {action: "used", actor: tx-sender}
            )
            (ok true)
        )
    )
)

;; New Analytics Functions
(define-read-only (get-key-analytics (key-id uint))
    (map-get? key-analytics {key-id: key-id})
)

;; Synthetic Asset Contract
;; Implements minting, burning, transfers, and price oracle functionality

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INSUFFICIENT-TOKEN-BALANCE (err u101))
(define-constant ERR-INVALID-TOKEN-AMOUNT (err u102))
(define-constant ERR-ORACLE-PRICE-EXPIRED (err u103))
(define-constant ERR-INSUFFICIENT-COLLATERAL-DEPOSIT (err u104))
(define-constant ERR-BELOW-MINIMUM-COLLATERAL-THRESHOLD (err u105))

;; Constants
(define-constant CONTRACT-ADMINISTRATOR tx-sender)
(define-constant ORACLE-PRICE-EXPIRY-BLOCKS u900) ;; 15 minutes in blocks
(define-constant REQUIRED-COLLATERAL-RATIO u150) ;; 150%
(define-constant LIQUIDATION-THRESHOLD-RATIO u120) ;; 120%
(define-constant MINIMUM-SYNTHETIC-TOKEN-MINT u100000000) ;; 1.00 tokens (8 decimals)

;; Data variables
(define-data-var oracle-price-last-update-block uint u0)
(define-data-var oracle-current-asset-price uint u0)
(define-data-var synthetic-token-total-supply uint u0)

;; Data maps
(define-map synthetic-token-holder-balances principal uint)
(define-map user-collateral-vault
    principal
    {
        deposited-collateral-amount: uint,
        minted-synthetic-tokens: uint,
        collateral-locked-at-price: uint
    }
)

;; Read-only functions
(define-read-only (get-synthetic-token-balance (token-holder principal))
    (default-to u0 (map-get? synthetic-token-holder-balances token-holder))
)

(define-read-only (get-synthetic-token-supply)
    (var-get synthetic-token-total-supply)
)

(define-read-only (get-oracle-asset-price)
    (var-get oracle-current-asset-price)
)

(define-read-only (get-user-vault-details (vault-owner principal))
    (map-get? user-collateral-vault vault-owner)
)

(define-read-only (calculate-vault-collateral-ratio (vault-owner principal))
    (let (
        (vault-details (unwrap! (get-user-vault-details vault-owner) (err u0)))
        (current-market-price (var-get oracle-current-asset-price))
    )
    (if (> (get minted-synthetic-tokens vault-details) u0)
        (ok (* (/ (* (get deposited-collateral-amount vault-details) u100) 
                  (* (get minted-synthetic-tokens vault-details) current-market-price))
               u100))
        (err u0)))
)

;; Private functions
(define-private (process-token-transfer (sender-address principal) (recipient-address principal) (transfer-amount uint))
    (let (
        (sender-token-balance (get-synthetic-token-balance sender-address))
    )
    (if (and
            (>= sender-token-balance transfer-amount)
            (is-some (map-get? synthetic-token-holder-balances sender-address))
        )
        (begin
            (map-set synthetic-token-holder-balances sender-address 
                     (- sender-token-balance transfer-amount))
            (map-set synthetic-token-holder-balances recipient-address 
                     (+ (get-synthetic-token-balance recipient-address) transfer-amount))
            (ok true))
        ERR-INSUFFICIENT-TOKEN-BALANCE))
)

;; Public functions
(define-public (update-oracle-price (new-asset-price uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-ADMINISTRATOR) ERR-UNAUTHORIZED-ACCESS)
        (var-set oracle-current-asset-price new-asset-price)
        (var-set oracle-price-last-update-block block-height)
        (ok true))
)

(define-public (mint-synthetic-tokens (token-amount uint))
    (let (
        (required-base-collateral (* token-amount (/ (var-get oracle-current-asset-price) u100)))
        (minimum-required-collateral (* required-base-collateral (/ REQUIRED-COLLATERAL-RATIO u100)))
    )
    (asserts! (>= token-amount MINIMUM-SYNTHETIC-TOKEN-MINT) ERR-INVALID-TOKEN-AMOUNT)
    (asserts! (>= (- block-height (var-get oracle-price-last-update-block)) 
                 ORACLE-PRICE-EXPIRY-BLOCKS) 
              ERR-ORACLE-PRICE-EXPIRED)
    
    (match (stx-transfer? minimum-required-collateral tx-sender (as-contract tx-sender))
        success
        (begin
            (map-set user-collateral-vault tx-sender
                {
                    deposited-collateral-amount: minimum-required-collateral,
                    minted-synthetic-tokens: token-amount,
                    collateral-locked-at-price: (var-get oracle-current-asset-price)
                })
            (map-set synthetic-token-holder-balances tx-sender 
                (+ (get-synthetic-token-balance tx-sender) token-amount))
            (var-set synthetic-token-total-supply 
                     (+ (var-get synthetic-token-total-supply) token-amount))
            (ok true))
        error ERR-INSUFFICIENT-COLLATERAL-DEPOSIT))
)

(define-public (burn-synthetic-tokens (token-amount uint))
    (let (
        (vault-details (unwrap! (get-user-vault-details tx-sender) 
                               ERR-UNAUTHORIZED-ACCESS))
        (collateral-return-amount (/ (* (get deposited-collateral-amount vault-details) 
                                      token-amount)
                                   (get minted-synthetic-tokens vault-details)))
    )
    (asserts! (>= (get-synthetic-token-balance tx-sender) token-amount) 
              ERR-INSUFFICIENT-TOKEN-BALANCE)
    
    (try! (as-contract (stx-transfer? collateral-return-amount
                                     (as-contract tx-sender)
                                     tx-sender)))
    
    (map-set user-collateral-vault tx-sender
        {
            deposited-collateral-amount: (- (get deposited-collateral-amount vault-details) 
                                          collateral-return-amount),
            minted-synthetic-tokens: (- (get minted-synthetic-tokens vault-details) 
                                      token-amount),
            collateral-locked-at-price: (var-get oracle-current-asset-price)
        })
    
    (map-set synthetic-token-holder-balances tx-sender 
             (- (get-synthetic-token-balance tx-sender) token-amount))
    (var-set synthetic-token-total-supply 
             (- (var-get synthetic-token-total-supply) token-amount))
    (ok true))
)

(define-public (transfer-synthetic-tokens (recipient-address principal) (transfer-amount uint))
    (begin
        (asserts! (not (is-eq tx-sender recipient-address)) ERR-UNAUTHORIZED-ACCESS)
        (process-token-transfer tx-sender recipient-address transfer-amount))
)

(define-public (deposit-additional-collateral (collateral-amount uint))
    (let (
        (vault-details (default-to 
            {
                deposited-collateral-amount: u0, 
                minted-synthetic-tokens: u0, 
                collateral-locked-at-price: u0
            }
            (get-user-vault-details tx-sender)))
    )
    (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
    
    (map-set user-collateral-vault tx-sender
        {
            deposited-collateral-amount: (+ (get deposited-collateral-amount vault-details) 
                                          collateral-amount),
            minted-synthetic-tokens: (get minted-synthetic-tokens vault-details),
            collateral-locked-at-price: (var-get oracle-current-asset-price)
        })
    (ok true))
)

(define-public (liquidate-undercollateralized-vault (vault-owner principal))
    (let (
        (vault-details (unwrap! (get-user-vault-details vault-owner) 
                               ERR-UNAUTHORIZED-ACCESS))
        (current-collateral-ratio (unwrap! (calculate-vault-collateral-ratio vault-owner) 
                                         ERR-UNAUTHORIZED-ACCESS))
    )
    (asserts! (< current-collateral-ratio LIQUIDATION-THRESHOLD-RATIO) 
              ERR-UNAUTHORIZED-ACCESS)
    
    ;; Transfer collateral to liquidator
    (try! (as-contract (stx-transfer? (get deposited-collateral-amount vault-details)
                                     (as-contract tx-sender)
                                     tx-sender)))
    
    ;; Clear the vault
    (map-delete user-collateral-vault vault-owner)
    
    ;; Burn the synthetic tokens
    (map-set synthetic-token-holder-balances vault-owner u0)
    (var-set synthetic-token-total-supply 
             (- (var-get synthetic-token-total-supply) 
                (get minted-synthetic-tokens vault-details)))
    (ok true))
)
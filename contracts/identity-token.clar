;; TwinVerse Identity Token Contract
;; A foundational smart contract for registering and interacting with digital twins in a decentralized ecosystem
;; Implements minting, burning, transfer, staking, and access control for twin ownership and simulation authorization

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INSUFFICIENT-BALANCE u101)
(define-constant ERR-INSUFFICIENT-STAKE u102)
(define-constant ERR-MAX-SUPPLY u103)
(define-constant ERR-PAUSED u104)
(define-constant ERR-NIL-ADDRESS u105)

(define-constant TOKEN-NAME "TwinVerse Token")
(define-constant TOKEN-SYMBOL "TVT")
(define-constant TOKEN-DECIMALS u6)
(define-constant MAX-SUPPLY u100000000)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Data Variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var total-supply uint u0)

(define-map balances principal uint)
(define-map stakes principal uint)
(define-map twin-access principal bool)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Internal Helpers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

(define-private (ensure-not-paused)
  (asserts! (not (var-get paused)) (err ERR-PAUSED))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Admin Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) (err ERR-NIL-ADDRESS))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set paused pause)
    (ok pause)
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Token Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (let ((new-supply (+ (var-get total-supply) amount)))
      (asserts! (<= new-supply MAX-SUPPLY) (err ERR-MAX-SUPPLY))
      (map-set balances recipient (+ amount (default-to u0 (map-get? balances recipient))))
      (var-set total-supply new-supply)
      (ok true)
    )
  )
)

(define-public (burn (amount uint))
  (begin
    (ensure-not-paused)
    (let ((balance (default-to u0 (map-get? balances tx-sender))))
      (asserts! (>= balance amount) (err ERR-INSUFFICIENT-BALANCE))
      (map-set balances tx-sender (- balance amount))
      (var-set total-supply (- (var-get total-supply) amount))
      (ok true)
    )
  )
)

(define-public (transfer (to principal) (amount uint))
  (begin
    (ensure-not-paused)
    (let ((sender-bal (default-to u0 (map-get? balances tx-sender))))
      (asserts! (>= sender-bal amount) (err ERR-INSUFFICIENT-BALANCE))
      (map-set balances tx-sender (- sender-bal amount))
      (map-set balances to (+ amount (default-to u0 (map-get? balances to))))
      (ok true)
    )
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Governance + Simulation Access
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public (stake (amount uint))
  (begin
    (ensure-not-paused)
    (let ((bal (default-to u0 (map-get? balances tx-sender))))
      (asserts! (>= bal amount) (err ERR-INSUFFICIENT-BALANCE))
      (map-set balances tx-sender (- bal amount))
      (map-set stakes tx-sender (+ amount (default-to u0 (map-get? stakes tx-sender))))
      (ok true)
    )
  )
)

(define-public (unstake (amount uint))
  (begin
    (ensure-not-paused)
    (let ((stk (default-to u0 (map-get? stakes tx-sender))))
      (asserts! (>= stk amount) (err ERR-INSUFFICIENT-STAKE))
      (map-set stakes tx-sender (- stk amount))
      (map-set balances tx-sender (+ amount (default-to u0 (map-get? balances tx-sender))))
      (ok true)
    )
  )
)

(define-public (grant-access (user principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (map-set twin-access user true)
    (ok true)
  )
)

(define-read-only (has-access (user principal))
  (ok (is-some (map-get? twin-access user)))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; View Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-read-only (get-balance (user principal))
  (ok (default-to u0 (map-get? balances user)))
)

(define-read-only (get-stake (user principal))
  (ok (default-to u0 (map-get? stakes user)))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-read-only (is-paused)
  (ok (var-get paused))
)

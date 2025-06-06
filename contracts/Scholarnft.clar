(define-constant contract-name "ScholarNFT")
(define-constant contract-version "1.0.0")
(define-non-fungible-token scholar-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-wrong-commission (err u103))
(define-constant err-not-found (err u104))
(define-constant err-metadata-frozen (err u105))
(define-constant err-mint-limit (err u106))
(define-constant err-insufficient-funds (err u107))
(define-constant err-milestone-not-ready (err u108))
(define-constant err-milestone-already-claimed (err u109))
(define-constant err-invalid-milestone (err u110))
(define-constant err-scholarship-complete (err u111))

(define-data-var last-token-id uint u0)
(define-data-var mint-limit uint u10000)
(define-data-var mint-price uint u1000000)

(define-map token-count principal uint)
(define-map market {token-id: uint} {price: uint, commission: principal})

(define-map scholarships uint {
    student: principal,
    sponsor: principal,
    total-amount: uint,
    claimed-amount: uint,
    milestones-completed: uint,
    total-milestones: uint,
    active: bool,
    created-at: uint
})

(define-map milestones {scholarship-id: uint, milestone-id: uint} {
    description: (string-ascii 256),
    amount: uint,
    completed: bool,
    verified-by: (optional principal),
    completed-at: (optional uint)
})

(define-map student-profiles principal {
    name: (string-ascii 64),
    field-of-study: (string-ascii 128),
    institution: (string-ascii 128),
    gpa: uint,
    verified: bool
})

(define-map sponsor-profiles principal {
    name: (string-ascii 64),
    organization: (string-ascii 128),
    total-sponsored: uint,
    active-scholarships: uint
})

(define-public (get-last-token-id)
    (ok (var-get last-token-id))
)

;; (define-public (get-token-uri (token-id uint))
;;     (ok (some (concat "https://scholarnft.com/metadata/" (uint-to-ascii token-id))))
;; )

(define-public (get-owner (token-id uint))
    (ok (nft-get-owner? scholar-nft token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (nft-transfer? scholar-nft token-id sender recipient)
    )
)

(define-public (create-student-profile (name (string-ascii 64)) (field-of-study (string-ascii 128)) (institution (string-ascii 128)) (gpa uint))
    (begin
        (map-set student-profiles tx-sender {
            name: name,
            field-of-study: field-of-study,
            institution: institution,
            gpa: gpa,
            verified: false
        })
        (ok true)
    )
)

(define-public (create-sponsor-profile (name (string-ascii 64)) (organization (string-ascii 128)))
    (begin
        (map-set sponsor-profiles tx-sender {
            name: name,
            organization: organization,
            total-sponsored: u0,
            active-scholarships: u0
        })
        (ok true)
    )
)

(define-public (create-scholarship (student principal) (total-amount uint) (total-milestones uint))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (asserts! (> total-amount u0) err-insufficient-funds)
        (asserts! (> total-milestones u0) err-invalid-milestone)
        (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
        (try! (nft-mint? scholar-nft token-id student))
        (map-set scholarships token-id {
            student: student,
            sponsor: tx-sender,
            total-amount: total-amount,
            claimed-amount: u0,
            milestones-completed: u0,
            total-milestones: total-milestones,
            active: true,
            created-at: stacks-block-height
        })
        (match (map-get? sponsor-profiles tx-sender)
            sponsor-data (map-set sponsor-profiles tx-sender (merge sponsor-data {
                total-sponsored: (+ (get total-sponsored sponsor-data) total-amount),
                active-scholarships: (+ (get active-scholarships sponsor-data) u1)
            }))
            (map-set sponsor-profiles tx-sender {
                name: "",
                organization: "",
                total-sponsored: total-amount,
                active-scholarships: u1
            })
        )
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-public (add-milestone (scholarship-id uint) (milestone-id uint) (description (string-ascii 256)) (amount uint))
    (let
        (
            (scholarship (unwrap! (map-get? scholarships scholarship-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get sponsor scholarship)) err-not-token-owner)
        (asserts! (get active scholarship) err-scholarship-complete)
        (map-set milestones {scholarship-id: scholarship-id, milestone-id: milestone-id} {
            description: description,
            amount: amount,
            completed: false,
            verified-by: none,
            completed-at: none
        })
        (ok true)
    )
)

(define-public (complete-milestone (scholarship-id uint) (milestone-id uint))
    (let
        (
            (scholarship (unwrap! (map-get? scholarships scholarship-id) err-not-found))
            (milestone (unwrap! (map-get? milestones {scholarship-id: scholarship-id, milestone-id: milestone-id}) err-not-found))
        )
        (asserts! (is-eq tx-sender (get student scholarship)) err-not-token-owner)
        (asserts! (not (get completed milestone)) err-milestone-already-claimed)
        (asserts! (get active scholarship) err-scholarship-complete)
        (map-set milestones {scholarship-id: scholarship-id, milestone-id: milestone-id} (merge milestone {
            completed: true,
            verified-by: (some tx-sender),
            completed-at: (some stacks-block-height)
        }))
        (ok true)
    )
)

(define-public (verify-and-release-funds (scholarship-id uint) (milestone-id uint))
    (let
        (
            (scholarship (unwrap! (map-get? scholarships scholarship-id) err-not-found))
            (milestone (unwrap! (map-get? milestones {scholarship-id: scholarship-id, milestone-id: milestone-id}) err-not-found))
        )
        (asserts! (is-eq tx-sender (get sponsor scholarship)) err-not-token-owner)
        (asserts! (get completed milestone) err-milestone-not-ready)
        (asserts! (get active scholarship) err-scholarship-complete)
        (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get student scholarship))))
        (map-set scholarships scholarship-id (merge scholarship {
            claimed-amount: (+ (get claimed-amount scholarship) (get amount milestone)),
            milestones-completed: (+ (get milestones-completed scholarship) u1)
        }))
        (let
            (
                (updated-scholarship (unwrap! (map-get? scholarships scholarship-id) err-not-found))
            )
            (if (is-eq (get milestones-completed updated-scholarship) (get total-milestones updated-scholarship))
                (begin
                    (map-set scholarships scholarship-id (merge updated-scholarship {active: false}))
                    (match (map-get? sponsor-profiles (get sponsor scholarship))
                        sponsor-data (map-set sponsor-profiles (get sponsor scholarship) (merge sponsor-data {
                            active-scholarships: (- (get active-scholarships sponsor-data) u1)
                        }))
                        true
                    )
                )
                true
            )
        )
        (ok true)
    )
)

(define-public (verify-student (student principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? student-profiles student)
            student-data (begin
                (map-set student-profiles student (merge student-data {verified: true}))
                (ok true)
            )
            err-not-found
        )
    )
)

(define-read-only (get-scholarship (scholarship-id uint))
    (map-get? scholarships scholarship-id)
)

(define-read-only (get-milestone (scholarship-id uint) (milestone-id uint))
    (map-get? milestones {scholarship-id: scholarship-id, milestone-id: milestone-id})
)

(define-read-only (get-student-profile (student principal))
    (map-get? student-profiles student)
)

(define-read-only (get-sponsor-profile (sponsor principal))
    (map-get? sponsor-profiles sponsor)
)

(define-read-only (get-scholarship-progress (scholarship-id uint))
    (match (map-get? scholarships scholarship-id)
        scholarship (ok {
            progress: (/ (* (get milestones-completed scholarship) u100) (get total-milestones scholarship)),
            funds-released: (/ (* (get claimed-amount scholarship) u100) (get total-amount scholarship)),
            active: (get active scholarship)
        })
        err-not-found
    )
)

(define-read-only (get-student-scholarships (student principal))
    (let
        (
            (token-ids (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))
        )
        (filter is-student-scholarship token-ids)
    )
)

(define-private (is-student-scholarship (token-id uint))
    (match (map-get? scholarships token-id)
        scholarship (is-eq (get student scholarship) tx-sender)
        false
    )
)

(define-read-only (get-mint-limit)
    (ok (var-get mint-limit))
)

(define-read-only (get-mint-price)
    (ok (var-get mint-price))
)

(define-public (set-mint-limit (limit uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set mint-limit limit))
    )
)

(define-public (set-mint-price (price uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (var-set mint-price price))
    )
)
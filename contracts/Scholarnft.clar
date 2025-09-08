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
(define-constant err-badge-already-earned (err u112))
(define-constant err-insufficient-reputation (err u113))
(define-constant err-invalid-badge-type (err u114))
(define-constant err-not-arbitrator (err u115))
(define-constant err-dispute-not-found (err u116))
(define-constant err-dispute-already-resolved (err u117))
(define-constant err-already-voted (err u118))
(define-constant err-escrow-not-found (err u119))
(define-constant err-insufficient-arbitrators (err u120))
(define-constant err-invalid-dispute-reason (err u121))

(define-data-var last-token-id uint u0)
(define-data-var mint-limit uint u10000)
(define-data-var mint-price uint u1000000)
(define-data-var dispute-counter uint u0)
(define-data-var arbitrator-fee uint u10000)

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

(define-map achievement-badges {student: principal, badge-type: (string-ascii 32)} {
    earned-at: uint,
    points: uint,
    description: (string-ascii 128),
    verified: bool
})

(define-map student-reputation principal {
    total-points: uint,
    badges-earned: uint,
    scholarships-completed: uint,
    average-completion-time: uint,
    reputation-level: (string-ascii 16)
})

(define-map badge-requirements (string-ascii 32) {
    min-scholarships: uint,
    min-gpa: uint,
    min-completion-rate: uint,
    points-awarded: uint,
    description: (string-ascii 128)
})

;; Escrow and Dispute Resolution Maps
(define-map arbitrators principal {
    verified: bool,
    cases-resolved: uint,
    reputation-score: uint,
    fee: uint,
    joined-at: uint
})

(define-map scholarship-escrow uint {
    scholarship-id: uint,
    total-amount: uint,
    released-amount: uint,
    arbitrator-1: principal,
    arbitrator-2: principal,
    arbitrator-3: principal,
    escrow-status: (string-ascii 16),
    created-at: uint
})

(define-map disputes uint {
    dispute-id: uint,
    scholarship-id: uint,
    plaintiff: principal,
    defendant: principal,
    reason: (string-ascii 256),
    amount-disputed: uint,
    created-at: uint,
    status: (string-ascii 16),
    resolution: (optional (string-ascii 256))
})

(define-map dispute-votes {dispute-id: uint, arbitrator: principal} {
    vote: (string-ascii 16),
    reason: (string-ascii 128),
    voted-at: uint
})

(define-map dispute-results uint {
    dispute-id: uint,
    winner: principal,
    amount-awarded: uint,
    votes-for-plaintiff: uint,
    votes-for-defendant: uint,
    resolved-at: uint
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

(define-public (setup-badge-requirements)
    (begin
        (map-set badge-requirements "excellence" {
            min-scholarships: u1,
            min-gpa: u90,
            min-completion-rate: u95,
            points-awarded: u100,
            description: "Awarded for exceptional academic performance"
        })
        (map-set badge-requirements "completion" {
            min-scholarships: u3,
            min-gpa: u70,
            min-completion-rate: u85,
            points-awarded: u75,
            description: "Awarded for consistent scholarship completion"
        })
        (map-set badge-requirements "milestone" {
            min-scholarships: u1,
            min-gpa: u60,
            min-completion-rate: u80,
            points-awarded: u50,
            description: "Awarded for reaching scholarship milestones"
        })
        (map-set badge-requirements "community" {
            min-scholarships: u5,
            min-gpa: u75,
            min-completion-rate: u90,
            points-awarded: u125,
            description: "Awarded for outstanding community contribution"
        })
        (ok true)
    )
)

(define-public (earn-badge (student principal) (badge-type (string-ascii 32)))
    (let
        (
            (requirements (unwrap! (map-get? badge-requirements badge-type) err-invalid-badge-type))
            (student-profile (unwrap! (map-get? student-profiles student) err-not-found))
            (reputation (default-to {
                total-points: u0,
                badges-earned: u0,
                scholarships-completed: u0,
                average-completion-time: u0,
                reputation-level: "novice"
            } (map-get? student-reputation student)))
        )
        (asserts! (is-none (map-get? achievement-badges {student: student, badge-type: badge-type})) err-badge-already-earned)
        (asserts! (>= (get gpa student-profile) (get min-gpa requirements)) err-insufficient-reputation)
        (asserts! (>= (get scholarships-completed reputation) (get min-scholarships requirements)) err-insufficient-reputation)
        (map-set achievement-badges {student: student, badge-type: badge-type} {
            earned-at: stacks-block-height,
            points: (get points-awarded requirements),
            description: (get description requirements),
            verified: true
        })
        (map-set student-reputation student (merge reputation {
            total-points: (+ (get total-points reputation) (get points-awarded requirements)),
            badges-earned: (+ (get badges-earned reputation) u1)
        }))
        (ok true)
    )
)

(define-public (update-reputation-after-scholarship (student principal))
    (let
        (
            (reputation (default-to {
                total-points: u0,
                badges-earned: u0,
                scholarships-completed: u0,
                average-completion-time: u0,
                reputation-level: "novice"
            } (map-get? student-reputation student)))
            (new-completion-count (+ (get scholarships-completed reputation) u1))
            (new-level (calculate-reputation-level (+ (get total-points reputation) u25)))
        )
        (map-set student-reputation student (merge reputation {
            scholarships-completed: new-completion-count,
            total-points: (+ (get total-points reputation) u25),
            reputation-level: new-level
        }))
        (ok true)
    )
)

(define-private (calculate-reputation-level (points uint))
    (if (>= points u500)
        "master"
        (if (>= points u250)
            "expert"
            (if (>= points u100)
                "advanced"
                (if (>= points u50)
                    "intermediate"
                    "novice"
                )
            )
        )
    )
)

(define-public (award-milestone-badge (scholarship-id uint) (milestone-id uint))
    (let
        (
            (scholarship (unwrap! (map-get? scholarships scholarship-id) err-not-found))
            (milestone (unwrap! (map-get? milestones {scholarship-id: scholarship-id, milestone-id: milestone-id}) err-not-found))
            (student (get student scholarship))
        )
        (asserts! (get completed milestone) err-milestone-not-ready)
        (asserts! (is-eq tx-sender (get sponsor scholarship)) err-not-token-owner)
        (unwrap! (earn-badge student "milestone") err-badge-already-earned)
        (ok true)
    )
)

(define-public (check-and-award-completion-badge (scholarship-id uint))
    (let
        (
            (scholarship (unwrap! (map-get? scholarships scholarship-id) err-not-found))
            (student (get student scholarship))
        )
        (asserts! (not (get active scholarship)) err-scholarship-complete)
        (asserts! (is-eq (get milestones-completed scholarship) (get total-milestones scholarship)) err-milestone-not-ready)
        (unwrap! (update-reputation-after-scholarship student) err-not-found)
        (unwrap! (earn-badge student "completion") err-badge-already-earned)
        (ok true)
    )
)

(define-public (nominate-for-excellence-badge (student principal))
    (let
        (
            (student-profile (unwrap! (map-get? student-profiles student) err-not-found))
            (reputation (unwrap! (map-get? student-reputation student) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (get verified student-profile) err-insufficient-reputation)
        (asserts! (>= (get gpa student-profile) u90) err-insufficient-reputation)
        (asserts! (>= (get scholarships-completed reputation) u1) err-insufficient-reputation)
        (unwrap! (earn-badge student "excellence") err-badge-already-earned)
        (ok true)
    )
)

(define-public (nominate-for-community-badge (student principal))
    (let
        (
            (student-profile (unwrap! (map-get? student-profiles student) err-not-found))
            (reputation (unwrap! (map-get? student-reputation student) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (get verified student-profile) err-insufficient-reputation)
        (asserts! (>= (get scholarships-completed reputation) u5) err-insufficient-reputation)
        (unwrap! (earn-badge student "community") err-badge-already-earned)
        (ok true)
    )
)

(define-read-only (get-student-badges (student principal))
    (let
        (
            (badge-types (list "excellence" "completion" "milestone" "community"))
        )
        (map get-badge-info badge-types)
    )
)

(define-private (get-badge-info (badge-type (string-ascii 32)))
    (map-get? achievement-badges {student: tx-sender, badge-type: badge-type})
)

(define-read-only (get-student-reputation-info (student principal))
    (map-get? student-reputation student)
)

(define-read-only (get-badge-requirements-info (badge-type (string-ascii 32)))
    (map-get? badge-requirements badge-type)
)

(define-read-only (calculate-student-rank (student principal))
    (match (map-get? student-reputation student)
        reputation (ok {
            rank: (get reputation-level reputation),
            points: (get total-points reputation),
            badges: (get badges-earned reputation),
            completed-scholarships: (get scholarships-completed reputation)
        })
        err-not-found
    )
)

(define-read-only (get-top-students)
    (let
        (
            (student-list (list tx-sender))
        )
        (map get-student-rank-info student-list)
    )
)

(define-private (get-student-rank-info (student principal))
    (match (map-get? student-reputation student)
        reputation {
            student: student,
            points: (get total-points reputation),
            level: (get reputation-level reputation)
        }
        {
            student: student,
            points: u0,
            level: "novice"
        }
    )
)

;; Arbitrator Management Functions
(define-public (register-arbitrator (fee uint))
    (begin
        (map-set arbitrators tx-sender {
            verified: false,
            cases-resolved: u0,
            reputation-score: u0,
            fee: fee,
            joined-at: stacks-block-height
        })
        (ok true)
    )
)

(define-public (verify-arbitrator (arbitrator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? arbitrators arbitrator)
            arbitrator-data (begin
                (map-set arbitrators arbitrator (merge arbitrator-data {verified: true}))
                (ok true)
            )
            err-not-found
        )
    )
)

;; Enhanced Scholarship Creation with Escrow
(define-public (create-scholarship-with-escrow (student principal) (total-amount uint) (total-milestones uint) (arbitrator-1 principal) (arbitrator-2 principal) (arbitrator-3 principal))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
            (arb1-data (unwrap! (map-get? arbitrators arbitrator-1) err-not-arbitrator))
            (arb2-data (unwrap! (map-get? arbitrators arbitrator-2) err-not-arbitrator))
            (arb3-data (unwrap! (map-get? arbitrators arbitrator-3) err-not-arbitrator))
        )
        ;; Validate arbitrators are verified
        (asserts! (get verified arb1-data) err-not-arbitrator)
        (asserts! (get verified arb2-data) err-not-arbitrator)
        (asserts! (get verified arb3-data) err-not-arbitrator)
        (asserts! (> total-amount u0) err-insufficient-funds)
        (asserts! (> total-milestones u0) err-invalid-milestone)
        
        ;; Transfer funds to contract for escrow
        (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
        (try! (nft-mint? scholar-nft token-id student))
        
        ;; Create scholarship record
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
        
        ;; Create escrow record
        (map-set scholarship-escrow token-id {
            scholarship-id: token-id,
            total-amount: total-amount,
            released-amount: u0,
            arbitrator-1: arbitrator-1,
            arbitrator-2: arbitrator-2,
            arbitrator-3: arbitrator-3,
            escrow-status: "active",
            created-at: stacks-block-height
        })
        
        ;; Update sponsor profile
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

;; Dispute Filing System
(define-public (file-dispute (scholarship-id uint) (reason (string-ascii 256)) (amount-disputed uint))
    (let
        (
            (scholarship (unwrap! (map-get? scholarships scholarship-id) err-not-found))
            (escrow (unwrap! (map-get? scholarship-escrow scholarship-id) err-escrow-not-found))
            (dispute-id (+ (var-get dispute-counter) u1))
        )
        ;; Only student or sponsor can file dispute
        (asserts! (or (is-eq tx-sender (get student scholarship)) (is-eq tx-sender (get sponsor scholarship))) err-not-token-owner)
        (asserts! (is-eq (get escrow-status escrow) "active") err-scholarship-complete)
        (asserts! (> amount-disputed u0) err-insufficient-funds)
        (asserts! (<= amount-disputed (get total-amount escrow)) err-insufficient-funds)
        
        ;; Determine defendant
        (let
            (
                (defendant (if (is-eq tx-sender (get student scholarship)) (get sponsor scholarship) (get student scholarship)))
            )
            ;; Create dispute record
            (map-set disputes dispute-id {
                dispute-id: dispute-id,
                scholarship-id: scholarship-id,
                plaintiff: tx-sender,
                defendant: defendant,
                reason: reason,
                amount-disputed: amount-disputed,
                created-at: stacks-block-height,
                status: "pending",
                resolution: none
            })
            
            ;; Update escrow status
            (map-set scholarship-escrow scholarship-id (merge escrow {escrow-status: "disputed"}))
            (var-set dispute-counter dispute-id)
            (ok dispute-id)
        )
    )
)

;; Arbitrator Voting System
(define-public (vote-on-dispute (dispute-id uint) (vote (string-ascii 16)) (reason (string-ascii 128)))
    (let
        (
            (dispute (unwrap! (map-get? disputes dispute-id) err-dispute-not-found))
            (scholarship-id (get scholarship-id dispute))
            (escrow (unwrap! (map-get? scholarship-escrow scholarship-id) err-escrow-not-found))
        )
        ;; Verify arbitrator is assigned to this escrow
        (asserts! (or 
            (is-eq tx-sender (get arbitrator-1 escrow))
            (is-eq tx-sender (get arbitrator-2 escrow))
            (is-eq tx-sender (get arbitrator-3 escrow))
        ) err-not-arbitrator)
        
        ;; Check dispute is still pending
        (asserts! (is-eq (get status dispute) "pending") err-dispute-already-resolved)
        
        ;; Check arbitrator hasn't already voted
        (asserts! (is-none (map-get? dispute-votes {dispute-id: dispute-id, arbitrator: tx-sender})) err-already-voted)
        
        ;; Valid vote options
        (asserts! (or (is-eq vote "plaintiff") (is-eq vote "defendant")) err-invalid-dispute-reason)
        
        ;; Record vote
        (map-set dispute-votes {dispute-id: dispute-id, arbitrator: tx-sender} {
            vote: vote,
            reason: reason,
            voted-at: stacks-block-height
        })
        
        ;; Check if we have majority (2 out of 3 votes)
        (try! (check-and-resolve-dispute dispute-id))
        (ok true)
    )
)

;; Dispute Resolution Logic
(define-private (check-and-resolve-dispute (dispute-id uint))
    (let
        (
            (dispute (unwrap! (map-get? disputes dispute-id) err-dispute-not-found))
            (scholarship-id (get scholarship-id dispute))
            (escrow (unwrap! (map-get? scholarship-escrow scholarship-id) err-escrow-not-found))
            (vote-1 (map-get? dispute-votes {dispute-id: dispute-id, arbitrator: (get arbitrator-1 escrow)}))
            (vote-2 (map-get? dispute-votes {dispute-id: dispute-id, arbitrator: (get arbitrator-2 escrow)}))
            (vote-3 (map-get? dispute-votes {dispute-id: dispute-id, arbitrator: (get arbitrator-3 escrow)}))
        )
        ;; Count votes for each side
        (let
            (
                (plaintiff-votes (+ 
                    (if (and (is-some vote-1) (is-eq (get vote (unwrap-panic vote-1)) "plaintiff")) u1 u0)
                    (+ (if (and (is-some vote-2) (is-eq (get vote (unwrap-panic vote-2)) "plaintiff")) u1 u0)
                       (if (and (is-some vote-3) (is-eq (get vote (unwrap-panic vote-3)) "plaintiff")) u1 u0))))
                (defendant-votes (+ 
                    (if (and (is-some vote-1) (is-eq (get vote (unwrap-panic vote-1)) "defendant")) u1 u0)
                    (+ (if (and (is-some vote-2) (is-eq (get vote (unwrap-panic vote-2)) "defendant")) u1 u0)
                       (if (and (is-some vote-3) (is-eq (get vote (unwrap-panic vote-3)) "defendant")) u1 u0))))
            )
            ;; Resolve if we have majority
            (if (>= plaintiff-votes u2)
                (begin
                    ;; Plaintiff wins - award disputed amount to plaintiff
                    (try! (as-contract (stx-transfer? (get amount-disputed dispute) tx-sender (get plaintiff dispute))))
                    (finalize-dispute-resolution dispute-id "plaintiff" plaintiff-votes defendant-votes)
                )
                (if (>= defendant-votes u2)
                    (begin
                        ;; Defendant wins - keep disputed amount in escrow
                        (finalize-dispute-resolution dispute-id "defendant" plaintiff-votes defendant-votes)
                    )
                    (ok false) ;; Not enough votes yet
                )
            )
        )
    )
)

;; Finalize Dispute Resolution
(define-private (finalize-dispute-resolution (dispute-id uint) (winner (string-ascii 16)) (plaintiff-votes uint) (defendant-votes uint))
    (let
        (
            (dispute (unwrap! (map-get? disputes dispute-id) err-dispute-not-found))
            (scholarship-id (get scholarship-id dispute))
            (escrow (unwrap! (map-get? scholarship-escrow scholarship-id) err-escrow-not-found))
            (winner-principal (if (is-eq winner "plaintiff") (get plaintiff dispute) (get defendant dispute)))
        )
        ;; Update dispute status
        (map-set disputes dispute-id (merge dispute {
            status: "resolved",
            resolution: (some (concat "Resolved in favor of " winner))
        }))
        
        ;; Record dispute result
        (map-set dispute-results dispute-id {
            dispute-id: dispute-id,
            winner: winner-principal,
            amount-awarded: (if (is-eq winner "plaintiff") (get amount-disputed dispute) u0),
            votes-for-plaintiff: plaintiff-votes,
            votes-for-defendant: defendant-votes,
            resolved-at: stacks-block-height
        })
        
        ;; Update escrow status back to active
        (map-set scholarship-escrow scholarship-id (merge escrow {escrow-status: "active"}))
        
        ;; Update arbitrator reputation scores
        (try! (update-arbitrator-reputation (get arbitrator-1 escrow)))
        (try! (update-arbitrator-reputation (get arbitrator-2 escrow)))
        (try! (update-arbitrator-reputation (get arbitrator-3 escrow)))
        (ok true)
    )
)

;; Update Arbitrator Reputation
(define-private (update-arbitrator-reputation (arbitrator principal))
    (match (map-get? arbitrators arbitrator)
        arbitrator-data (begin
            (map-set arbitrators arbitrator (merge arbitrator-data {
                cases-resolved: (+ (get cases-resolved arbitrator-data) u1),
                reputation-score: (+ (get reputation-score arbitrator-data) u10)
            }))
            (ok true)
        )
        err-not-found
    )
)

;; Emergency Release Function (for contract owner)
(define-public (emergency-release-funds (scholarship-id uint) (amount uint) (recipient principal))
    (let
        (
            (escrow (unwrap! (map-get? scholarship-escrow scholarship-id) err-escrow-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= amount (- (get total-amount escrow) (get released-amount escrow))) err-insufficient-funds)
        
        ;; Transfer funds
        (try! (as-contract (stx-transfer? amount tx-sender recipient)))
        
        ;; Update escrow
        (map-set scholarship-escrow scholarship-id (merge escrow {
            released-amount: (+ (get released-amount escrow) amount)
        }))
        (ok true)
    )
)

;; Read-only Functions for Escrow and Disputes
(define-read-only (get-arbitrator-info (arbitrator principal))
    (map-get? arbitrators arbitrator)
)

(define-read-only (get-escrow-info (scholarship-id uint))
    (map-get? scholarship-escrow scholarship-id)
)

(define-read-only (get-dispute-info (dispute-id uint))
    (map-get? disputes dispute-id)
)

(define-read-only (get-dispute-votes-info (dispute-id uint) (arbitrator principal))
    (map-get? dispute-votes {dispute-id: dispute-id, arbitrator: arbitrator})
)

(define-read-only (get-dispute-result (dispute-id uint))
    (map-get? dispute-results dispute-id)
)


(define-read-only (get-arbitrator-reputation (arbitrator principal))
    (map-get? arbitrators arbitrator)
)






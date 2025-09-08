;; Scholarship Marketplace and Smart Matching Contract
;; Connects students with suitable scholarship opportunities through intelligent matching

;; Error constants
(define-constant err-not-authorized (err u400))
(define-constant err-opportunity-not-found (err u401))
(define-constant err-already-applied (err u402))
(define-constant err-not-eligible (err u403))
(define-constant err-opportunity-expired (err u404))
(define-constant err-application-not-found (err u405))
(define-constant err-opportunity-closed (err u406))

;; Data variables
(define-data-var opportunity-id-nonce uint u0)
(define-data-var application-id-nonce uint u0)

;; Opportunity status
(define-constant status-open u1)
(define-constant status-closed u2)
(define-constant status-awarded u3)

;; Maps
(define-map scholarship-opportunities
    uint
    {
        sponsor: principal,
        title: (string-ascii 128),
        description: (string-ascii 500),
        amount: uint,
        field-requirements: (string-ascii 128),
        min-gpa: uint,
        institution-preference: (optional (string-ascii 128)),
        deadline-block: uint,
        max-recipients: uint,
        current-applications: uint,
        status: uint,
        created-at: uint
    }
)

(define-map scholarship-applications
    {opportunity-id: uint, applicant: principal}
    {
        application-id: uint,
        applied-at: uint,
        match-score: uint,
        status: (string-ascii 20),
        reviewed: bool
    }
)

(define-map student-applications
    principal
    {
        total-applications: uint,
        active-applications: uint,
        successful-applications: uint
    }
)

(define-map opportunity-matches
    {opportunity-id: uint, student: principal}
    {
        compatibility-score: uint,
        gpa-match: uint,
        field-match: bool,
        institution-match: bool,
        badge-bonus: uint,
        calculated-at: uint
    }
)

;; Create scholarship opportunity
(define-public (create-opportunity (title (string-ascii 128))
                                  (description (string-ascii 500))
                                  (amount uint)
                                  (field-requirements (string-ascii 128))
                                  (min-gpa uint)
                                  (institution-preference (optional (string-ascii 128)))
                                  (deadline-blocks uint)
                                  (max-recipients uint))
    (let ((opportunity-id (+ (var-get opportunity-id-nonce) u1))
          (deadline-block (+ stacks-block-height deadline-blocks)))
        (asserts! (> amount u0) err-not-authorized)
        (asserts! (> deadline-blocks u0) err-not-authorized)
        (asserts! (> max-recipients u0) err-not-authorized)
        (asserts! (<= min-gpa u400) err-not-authorized) ;; Max GPA 4.00
        
        (map-set scholarship-opportunities opportunity-id
            {
                sponsor: tx-sender,
                title: title,
                description: description,
                amount: amount,
                field-requirements: field-requirements,
                min-gpa: min-gpa,
                institution-preference: institution-preference,
                deadline-block: deadline-block,
                max-recipients: max-recipients,
                current-applications: u0,
                status: status-open,
                created-at: stacks-block-height
            }
        )
        
        (var-set opportunity-id-nonce opportunity-id)
        (ok opportunity-id)
    )
)



;; Helper functions for match scoring
(define-private (calculate-gpa-score (student-gpa uint) (min-gpa uint))
    (if (< student-gpa min-gpa)
        u0
        (let ((excess-gpa (- student-gpa min-gpa))
              (max-bonus u40)
              (bonus-calc (/ (* excess-gpa u2) u10)))
            (+ u20 (if (<= bonus-calc max-bonus) bonus-calc max-bonus))
        )
    )
)

(define-private (is-field-match (student-field (string-ascii 128)) (required-field (string-ascii 128)))
    ;; Simple field matching - in real implementation, this could be more sophisticated
    (is-eq student-field required-field)
)

(define-private (is-institution-match (student-institution (string-ascii 128)) (preferred-institution (optional (string-ascii 128))))
    (match preferred-institution
        institution (is-eq student-institution institution)
        true ;; No preference means all institutions match
    )
)



;; Get opportunity details
(define-read-only (get-opportunity (opportunity-id uint))
    (map-get? scholarship-opportunities opportunity-id)
)

;; Get student's application for opportunity
(define-read-only (get-application (opportunity-id uint) (student principal))
    (map-get? scholarship-applications {opportunity-id: opportunity-id, applicant: student})
)

;; Get student's application summary
(define-read-only (get-student-application-summary (student principal))
    (default-to 
        {total-applications: u0, active-applications: u0, successful-applications: u0}
        (map-get? student-applications student)
    )
)

;; Get match score details
(define-read-only (get-match-details (opportunity-id uint) (student principal))
    (map-get? opportunity-matches {opportunity-id: opportunity-id, student: student})
)

;; Get open opportunities (simplified - returns first few)
(define-read-only (get-open-opportunities)
    (ok {
        opportunity-1: (if (is-eq (get status (default-to {status: u0} (map-get? scholarship-opportunities u1))) status-open)
                          (map-get? scholarship-opportunities u1) none),
        opportunity-2: (if (is-eq (get status (default-to {status: u0} (map-get? scholarship-opportunities u2))) status-open)
                          (map-get? scholarship-opportunities u2) none),
        opportunity-3: (if (is-eq (get status (default-to {status: u0} (map-get? scholarship-opportunities u3))) status-open)
                          (map-get? scholarship-opportunities u3) none),
        total-opportunities: (var-get opportunity-id-nonce)
    })
)

;; Close opportunity (sponsor only)
(define-public (close-opportunity (opportunity-id uint))
    (match (map-get? scholarship-opportunities opportunity-id)
        opportunity
        (begin
            (asserts! (is-eq tx-sender (get sponsor opportunity)) err-not-authorized)
            (map-set scholarship-opportunities opportunity-id
                (merge opportunity {status: status-closed})
            )
            (ok true)
        )
        err-opportunity-not-found
    )
)

;; Award opportunity to student
(define-public (award-opportunity (opportunity-id uint) (student principal))
    (let ((opportunity (unwrap! (map-get? scholarship-opportunities opportunity-id) err-opportunity-not-found))
          (application (unwrap! (map-get? scholarship-applications {opportunity-id: opportunity-id, applicant: student}) err-application-not-found))
          (student-apps (unwrap-panic (map-get? student-applications student))))
        (asserts! (is-eq tx-sender (get sponsor opportunity)) err-not-authorized)
        (asserts! (is-eq (get status opportunity) status-open) err-opportunity-closed)
        
        ;; Mark opportunity as awarded
        (map-set scholarship-opportunities opportunity-id
            (merge opportunity {status: status-awarded})
        )
        
        ;; Update application status
        (map-set scholarship-applications {opportunity-id: opportunity-id, applicant: student}
            (merge application {status: "awarded", reviewed: true})
        )
        
        ;; Update student applications summary
        (map-set student-applications student
            (merge student-apps 
                {
                    active-applications: (- (get active-applications student-apps) u1),
                    successful-applications: (+ (get successful-applications student-apps) u1)
                }
            )
        )
        
        (ok true)
    )
)

;; Get marketplace statistics
(define-read-only (get-marketplace-stats)
    (ok {
        total-opportunities: (var-get opportunity-id-nonce),
        total-applications: (var-get application-id-nonce)
    })
)

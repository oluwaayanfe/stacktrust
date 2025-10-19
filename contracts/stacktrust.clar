(define-data-var current-block uint u0)
(define-map reputation-map principal uint)
(define-map rep-checkpoints principal uint)
(define-map loan-requests principal {amount: uint, deadline: uint, approved: bool})
(define-map bounty-list uint {poster: principal, description: (string-ascii 256), reward: uint, milestone: uint, status: (string-ascii 32)})
(define-map milestone-submissions {bounty-id: uint, milestone: uint} {submitter: principal, link: (string-ascii 256), approved: bool})
(define-map dao-proposals uint {proposer: principal, action-code: uint, parameters: (string-ascii 256), yes: uint, no: uint, deadline: uint})
(define-map reputation-stake principal uint)
(define-data-var proposal-counter uint u0)
(define-map loan-repayments principal {amount: uint, deadline: uint, paid: bool})
(define-map bounty-claims uint principal)

(define-constant MIN_REP_FOR_LOAN u50)
(define-constant DAO_MIN_REP u100)
(define-constant LOAN_PENALTY_REP u15)

;; Reputation System
(define-public (award-reputation (user principal) (points uint))
  (let ((current-rep (default-to u0 (map-get? reputation-map user))))
    (asserts! (map-set reputation-map user (+ current-rep points)) (err u400))
    (ok true)))

(define-public (slash-reputation (user principal) (points uint))
  (let ((current (default-to u0 (map-get? reputation-map user))))
    (begin
      (map-set reputation-map user (if (< points current) (- current points) u0))
      (ok true))))

;; Loan Protocol
(define-public (request-loan (amount uint) (deadline uint))
  (begin
    (asserts! (>= (default-to u0 (map-get? reputation-map tx-sender)) MIN_REP_FOR_LOAN) (err u100))
    (asserts! (map-set loan-requests tx-sender {amount: amount, deadline: deadline, approved: false}) (err u401))
    (ok "Loan requested")))

(define-public (approve-loan (borrower principal))
  (let ((loan (map-get? loan-requests borrower)))
    (match loan
      loan-data (begin
          (asserts! (map-set loan-requests borrower (merge loan-data {approved: true})) (err u402))
          (asserts! (map-set loan-repayments borrower 
            {amount: (get amount loan-data), deadline: (get deadline loan-data), paid: false}) (err u403))
          (ok true))
      (err u101))))

(define-public (repay-loan)
  (let ((repayment (map-get? loan-repayments tx-sender)))
    (match repayment
      repay-data (begin
        (asserts! (not (get paid repay-data)) (err u102))
        (asserts! (map-set loan-repayments tx-sender (merge repay-data {paid: true})) (err u410))
        (unwrap! (award-reputation tx-sender u20) (err u106))
        (ok "Loan repaid"))
      (err u103))))

(define-public (check-loan-default (borrower principal))
  (let ((repayment (map-get? loan-repayments borrower)))
    (match repayment
      repay-data (begin
        (asserts! (not (get paid repay-data)) (err u108))
        (asserts! (> burn-block-height (get deadline repay-data)) (err u109))
        (unwrap! (slash-reputation borrower LOAN_PENALTY_REP) (err u107))
        (ok "Defaulted and slashed"))
      (err u104))))

;; Bounty System
(define-public (post-bounty (id uint) (desc (string-ascii 256)) (reward uint) (milestones uint))
  (let ((bounty {poster: tx-sender, 
                description: desc, 
                reward: reward, 
                milestone: milestones, 
                status: "open"}))
    (asserts! (map-set bounty-list id bounty) (err u404))
    (ok "Bounty created")))

(define-public (claim-bounty (id uint))
  (begin
    (asserts! (is-none (map-get? bounty-claims id)) (err u105))
    (asserts! (map-set bounty-claims id tx-sender) (err u405))
    (ok "Bounty claimed")))

(define-public (submit-milestone (bounty-id uint) (milestone uint) (link (string-ascii 256)))
  (let ((submission {bounty-id: bounty-id, milestone: milestone})
        (submission-data {submitter: tx-sender, link: link, approved: false}))
    (asserts! (map-set milestone-submissions submission submission-data) (err u406))
    (ok "Milestone submitted")))

(define-public (grade-submission (bounty-id uint) (milestone uint) (score uint))
  (let ((submission (map-get? milestone-submissions {bounty-id: bounty-id, milestone: milestone})))
    (match submission
      submission-data 
        (let ((submission-key {bounty-id: bounty-id, milestone: milestone}))
          (if (>= score u70)
              (begin
                (asserts! (map-set milestone-submissions submission-key
                  (merge submission-data {approved: true})) (err u407))
                (unwrap! (award-reputation (get submitter submission-data) u10) (err u110))
                (ok "Approved"))
              (begin
                (unwrap! (slash-reputation (get submitter submission-data) u5) (err u111))
                (ok "Rejected"))))
      (err u200))))

;; DAO Governance
(define-public (submit-proposal (action-code uint) (params (string-ascii 256)) (deadline uint))
  (begin
    (asserts! (>= (default-to u0 (map-get? reputation-map tx-sender)) DAO_MIN_REP) (err u301))
    (let ((id (+ (var-get proposal-counter) u1))
          (new-proposal {proposer: tx-sender, 
                        action-code: action-code, 
                        parameters: params, 
                        yes: u0, 
                        no: u0, 
                        deadline: deadline}))
      (var-set proposal-counter id)
      (asserts! (map-set dao-proposals id new-proposal) (err u408))
      (ok id))))

(define-public (vote-on-proposal (id uint) (support bool))
  (let ((proposal (map-get? dao-proposals id)))
    (match proposal
      p (begin
        (asserts! (< burn-block-height (get deadline p)) (err u303))
        (let ((updated-proposal (merge p 
                                {yes: (if support (+ (get yes p) u1) (get yes p)),
                                 no: (if support (get no p) (+ (get no p) u1))})))
          (asserts! (map-set dao-proposals id updated-proposal) (err u409))
          (ok "Vote cast")))
      (err u302))))

;; International Coordination Contract
;; Facilitates cross-border spectrum coordination and harmonization

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-AGREEMENT (err u501))
(define-constant ERR-AGREEMENT-NOT-FOUND (err u502))
(define-constant ERR-COUNTRY-NOT-FOUND (err u503))
(define-constant ERR-COORDINATION-FAILED (err u504))
(define-constant ERR-INVALID-FREQUENCY-PLAN (err u505))
(define-constant ERR-TREATY-VIOLATION (err u506))
(define-constant ERR-INVALID-INPUT (err u507))
(define-constant ERR-HARMONIZATION-CONFLICT (err u508))

;; Agreement types
(define-constant AGREEMENT-TYPE-BILATERAL "BILATERAL")
(define-constant AGREEMENT-TYPE-MULTILATERAL "MULTILATERAL")
(define-constant AGREEMENT-TYPE-ITU-REGION "ITU_REGION")
(define-constant AGREEMENT-TYPE-BORDER-COORD "BORDER_COORD")

;; Coordination status
(define-constant STATUS-PROPOSED "PROPOSED")
(define-constant STATUS-NEGOTIATING "NEGOTIATING")
(define-constant STATUS-APPROVED "APPROVED")
(define-constant STATUS-ACTIVE "ACTIVE")
(define-constant STATUS-SUSPENDED "SUSPENDED")
(define-constant STATUS-TERMINATED "TERMINATED")

;; ITU Regions
(define-constant ITU-REGION-1 "REGION_1") ;; Europe, Africa, Middle East, Mongolia, Russia
(define-constant ITU-REGION-2 "REGION_2") ;; Americas
(define-constant ITU-REGION-3 "REGION_3") ;; Asia-Pacific

;; Data Variables
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var next-agreement-id uint u1)
(define-data-var next-coordination-id uint u1)
(define-data-var next-country-id uint u1)

;; Data Maps
(define-map international-agreements
  { agreement-id: uint }
  {
    agreement-name: (string-ascii 100),
    agreement-type: (string-ascii 15),
    participating-countries: (list 20 uint),
    frequency-bands: (list 10 { start: uint, end: uint }),
    coordination-procedures: (string-ascii 500),
    effective-date: uint,
    expiry-date: (optional uint),
    status: (string-ascii 15),
    itu-region: (string-ascii 10),
    treaty-reference: (string-ascii 100),
    last-updated: uint
  }
)

(define-map country-registry
  { country-id: uint }
  {
    country-code: (string-ascii 3),
    country-name: (string-ascii 50),
    itu-region: (string-ascii 10),
    regulatory-authority: (string-ascii 100),
    contact-info: (string-ascii 200),
    spectrum-plan: (string-ascii 300),
    coordination-representative: principal,
    is-active: bool,
    joined-at: uint
  }
)

(define-map coordination-requests
  { coordination-id: uint }
  {
    requesting-country: uint,
    target-countries: (list 10 uint),
    frequency-range: { start: uint, end: uint },
    geographic-area: (string-ascii 200),
    coordination-type: (string-ascii 20),
    technical-parameters: (string-ascii 300),
    justification: (string-ascii 500),
    submitted-at: uint,
    status: (string-ascii 15),
    responses: (list 10 { country: uint, response: (string-ascii 10), timestamp: uint }),
    resolution: (optional (string-ascii 300))
  }
)

(define-map frequency-harmonization
  { frequency-band: { start: uint, end: uint }, itu-region: (string-ascii 10) }
  {
    primary-allocation: (string-ascii 50),
    secondary-allocations: (list 5 (string-ascii 50)),
    footnotes: (list 10 (string-ascii 100)),
    coordination-required: bool,
    protection-criteria: (string-ascii 200),
    last-wrc-update: uint
  }
)

(define-map border-coordination
  { country-1: uint, country-2: uint, frequency-band: { start: uint, end: uint } }
  {
    coordination-distance: uint,
    power-limits: { country-1-limit: uint, country-2-limit: uint },
    coordination-procedures: (string-ascii 300),
    notification-threshold: uint,
    agreement-reference: uint,
    last-coordination: uint,
    active-notifications: uint
  }
)

(define-map treaty-obligations
  { country-id: uint, treaty-id: uint }
  {
    treaty-name: (string-ascii 100),
    obligations: (string-ascii 500),
    compliance-status: (string-ascii 20),
    last-review: uint,
    next-review: uint,
    violations: (list 5 (string-ascii 200))
  }
)

(define-map harmonization-proposals
  { proposal-id: uint }
  {
    proposing-country: uint,
    frequency-range: { start: uint, end: uint },
    proposed-allocation: (string-ascii 50),
    affected-regions: (list 3 (string-ascii 10)),
    technical-justification: (string-ascii 500),
    economic-impact: (string-ascii 300),
    implementation-timeline: uint,
    status: (string-ascii 15),
    support-votes: uint,
    opposition-votes: uint
  }
)

;; Read-only functions
(define-read-only (get-international-agreement (agreement-id uint))
  (map-get? international-agreements { agreement-id: agreement-id })
)

(define-read-only (get-country-info (country-id uint))
  (map-get? country-registry { country-id: country-id })
)

(define-read-only (get-coordination-request (coordination-id uint))
  (map-get? coordination-requests { coordination-id: coordination-id })
)

(define-read-only (get-frequency-harmonization (freq-start uint) (freq-end uint) (itu-region (string-ascii 10)))
  (map-get? frequency-harmonization { frequency-band: { start: freq-start, end: freq-end }, itu-region: itu-region })
)

(define-read-only (get-border-coordination (country-1 uint) (country-2 uint) (freq-start uint) (freq-end uint))
  (map-get? border-coordination { country-1: country-1, country-2: country-2, frequency-band: { start: freq-start, end: freq-end } })
)

(define-read-only (get-treaty-obligations (country-id uint) (treaty-id uint))
  (map-get? treaty-obligations { country-id: country-id, treaty-id: treaty-id })
)

(define-read-only (is-coordination-required (freq-start uint) (freq-end uint) (itu-region (string-ascii 10)))
  (match (get-frequency-harmonization freq-start freq-end itu-region)
    harmonization-data (get coordination-required harmonization-data)
    false
  )
)

(define-read-only (get-harmonization-proposal (proposal-id uint))
  (map-get? harmonization-proposals { proposal-id: proposal-id })
)

;; Private functions
(define-private (is-authorized (caller principal))
  (is-eq caller (var-get contract-owner))
)

(define-private (is-valid-itu-region (region (string-ascii 10)))
  (or
    (is-eq region ITU-REGION-1)
    (or
      (is-eq region ITU-REGION-2)
      (is-eq region ITU-REGION-3)
    )
  )
)

(define-private (is-valid-frequency-range (start uint) (end uint))
  (and (> start u0) (> end start) (< (- end start) u10000000)) ;; Max 10 GHz range
)

(define-private (is-country-representative (country-id uint) (caller principal))
  (match (get-country-info country-id)
    country-data (is-eq caller (get coordination-representative country-data))
    false
  )
)

;; Public functions
(define-public (register-country (country-code (string-ascii 3))
                                (country-name (string-ascii 50))
                                (itu-region (string-ascii 10))
                                (regulatory-authority (string-ascii 100))
                                (contact-info (string-ascii 200))
                                (spectrum-plan (string-ascii 300))
                                (representative principal))
  (let
    (
      (country-id (var-get next-country-id))
    )
    (begin
      (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (> (len country-code) u0) ERR-INVALID-INPUT)
      (asserts! (> (len country-name) u0) ERR-INVALID-INPUT)
      (asserts! (is-valid-itu-region itu-region) ERR-INVALID-INPUT)

      (map-set country-registry
        { country-id: country-id }
        {
          country-code: country-code,
          country-name: country-name,
          itu-region: itu-region,
          regulatory-authority: regulatory-authority,
          contact-info: contact-info,
          spectrum-plan: spectrum-plan,
          coordination-representative: representative,
          is-active: true,
          joined-at: block-height
        }
      )

      (var-set next-country-id (+ country-id u1))
      (ok country-id)
    )
  )
)

(define-public (create-international-agreement (agreement-name (string-ascii 100))
                                              (agreement-type (string-ascii 15))
                                              (participating-countries (list 20 uint))
                                              (frequency-bands (list 10 { start: uint, end: uint }))
                                              (coordination-procedures (string-ascii 500))
                                              (expiry-date (optional uint))
                                              (itu-region (string-ascii 10))
                                              (treaty-reference (string-ascii 100)))
  (let
    (
      (agreement-id (var-get next-agreement-id))
    )
    (begin
      (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (> (len agreement-name) u0) ERR-INVALID-INPUT)
      (asserts! (> (len participating-countries) u0) ERR-INVALID-INPUT)
      (asserts! (> (len frequency-bands) u0) ERR-INVALID-INPUT)
      (asserts! (is-valid-itu-region itu-region) ERR-INVALID-INPUT)

      (map-set international-agreements
        { agreement-id: agreement-id }
        {
          agreement-name: agreement-name,
          agreement-type: agreement-type,
          participating-countries: participating-countries,
          frequency-bands: frequency-bands,
          coordination-procedures: coordination-procedures,
          effective-date: block-height,
          expiry-date: expiry-date,
          status: STATUS-ACTIVE,
          itu-region: itu-region,
          treaty-reference: treaty-reference,
          last-updated: block-height
        }
      )

      (var-set next-agreement-id (+ agreement-id u1))
      (ok agreement-id)
    )
  )
)

(define-public (submit-coordination-request (target-countries (list 10 uint))
                                           (freq-start uint) (freq-end uint)
                                           (geographic-area (string-ascii 200))
                                           (coordination-type (string-ascii 20))
                                           (technical-parameters (string-ascii 300))
                                           (justification (string-ascii 500)))
  (let
    (
      (coordination-id (var-get next-coordination-id))
      (requesting-country-id u1) ;; Simplified - would need to lookup based on tx-sender
    )
    (begin
      (asserts! (is-valid-frequency-range freq-start freq-end) ERR-INVALID-FREQUENCY-PLAN)
      (asserts! (> (len target-countries) u0) ERR-INVALID-INPUT)
      (asserts! (> (len justification) u0) ERR-INVALID-INPUT)

      (map-set coordination-requests
        { coordination-id: coordination-id }
        {
          requesting-country: requesting-country-id,
          target-countries: target-countries,
          frequency-range: { start: freq-start, end: freq-end },
          geographic-area: geographic-area,
          coordination-type: coordination-type,
          technical-parameters: technical-parameters,
          justification: justification,
          submitted-at: block-height,
          status: STATUS-PROPOSED,
          responses: (list),
          resolution: none
        }
      )

      (var-set next-coordination-id (+ coordination-id u1))
      (ok coordination-id)
    )
  )
)

(define-public (respond-to-coordination (coordination-id uint) (response (string-ascii 10)) (country-id uint))
  (let
    (
      (request-data (unwrap! (get-coordination-request coordination-id) ERR-AGREEMENT-NOT-FOUND))
      (current-responses (get responses request-data))
      (new-response { country: country-id, response: response, timestamp: block-height })
    )
    (begin
      (asserts! (is-country-representative country-id tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (is-eq (get status request-data) STATUS-PROPOSED) ERR-INVALID-AGREEMENT)

      (map-set coordination-requests
        { coordination-id: coordination-id }
        (merge request-data {
          responses: (unwrap! (as-max-len? (append current-responses new-response) u10) ERR-INVALID-INPUT),
          status: STATUS-NEGOTIATING
        })
      )

      (ok true)
    )
  )
)

(define-public (establish-frequency-harmonization (freq-start uint) (freq-end uint)
                                                 (itu-region (string-ascii 10))
                                                 (primary-allocation (string-ascii 50))
                                                 (secondary-allocations (list 5 (string-ascii 50)))
                                                 (footnotes (list 10 (string-ascii 100)))
                                                 (coordination-required bool)
                                                 (protection-criteria (string-ascii 200)))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-frequency-range freq-start freq-end) ERR-INVALID-FREQUENCY-PLAN)
    (asserts! (is-valid-itu-region itu-region) ERR-INVALID-INPUT)
    (asserts! (> (len primary-allocation) u0) ERR-INVALID-INPUT)

    (map-set frequency-harmonization
      { frequency-band: { start: freq-start, end: freq-end }, itu-region: itu-region }
      {
        primary-allocation: primary-allocation,
        secondary-allocations: secondary-allocations,
        footnotes: footnotes,
        coordination-required: coordination-required,
        protection-criteria: protection-criteria,
        last-wrc-update: block-height
      }
    )

    (ok true)
  )
)

(define-public (setup-border-coordination (country-1 uint) (country-2 uint)
                                         (freq-start uint) (freq-end uint)
                                         (coordination-distance uint)
                                         (country-1-power-limit uint) (country-2-power-limit uint)
                                         (coordination-procedures (string-ascii 300))
                                         (notification-threshold uint)
                                         (agreement-reference uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-frequency-range freq-start freq-end) ERR-INVALID-FREQUENCY-PLAN)
    (asserts! (not (is-eq country-1 country-2)) ERR-INVALID-INPUT)
    (asserts! (> coordination-distance u0) ERR-INVALID-INPUT)

    (map-set border-coordination
      { country-1: country-1, country-2: country-2, frequency-band: { start: freq-start, end: freq-end } }
      {
        coordination-distance: coordination-distance,
        power-limits: { country-1-limit: country-1-power-limit, country-2-limit: country-2-power-limit },
        coordination-procedures: coordination-procedures,
        notification-threshold: notification-threshold,
        agreement-reference: agreement-reference,
        last-coordination: block-height,
        active-notifications: u0
      }
    )

    (ok true)
  )
)

(define-public (record-treaty-obligations (country-id uint) (treaty-id uint)
                                         (treaty-name (string-ascii 100))
                                         (obligations (string-ascii 500))
                                         (next-review-blocks uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (get-country-info country-id)) ERR-COUNTRY-NOT-FOUND)
    (asserts! (> (len treaty-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len obligations) u0) ERR-INVALID-INPUT)

    (map-set treaty-obligations
      { country-id: country-id, treaty-id: treaty-id }
      {
        treaty-name: treaty-name,
        obligations: obligations,
        compliance-status: "COMPLIANT",
        last-review: block-height,
        next-review: (+ block-height next-review-blocks),
        violations: (list)
      }
    )

    (ok true)
  )
)

(define-public (propose-harmonization (freq-start uint) (freq-end uint)
                                     (proposed-allocation (string-ascii 50))
                                     (affected-regions (list 3 (string-ascii 10)))
                                     (technical-justification (string-ascii 500))
                                     (economic-impact (string-ascii 300))
                                     (implementation-timeline uint))
  (let
    (
      (proposal-id (var-get next-agreement-id)) ;; Reuse counter
    )
    (begin
      (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (is-valid-frequency-range freq-start freq-end) ERR-INVALID-FREQUENCY-PLAN)
      (asserts! (> (len proposed-allocation) u0) ERR-INVALID-INPUT)
      (asserts! (> (len affected-regions) u0) ERR-INVALID-INPUT)
      (asserts! (> implementation-timeline u0) ERR-INVALID-INPUT)

      (map-set harmonization-proposals
        { proposal-id: proposal-id }
        {
          proposing-country: u1, ;; Simplified
          frequency-range: { start: freq-start, end: freq-end },
          proposed-allocation: proposed-allocation,
          affected-regions: affected-regions,
          technical-justification: technical-justification,
          economic-impact: economic-impact,
          implementation-timeline: implementation-timeline,
          status: STATUS-PROPOSED,
          support-votes: u0,
          opposition-votes: u0
        }
      )

      (ok proposal-id)
    )
  )
)

(define-public (vote-on-harmonization (proposal-id uint) (support bool) (country-id uint))
  (let
    (
      (proposal-data (unwrap! (get-harmonization-proposal proposal-id) ERR-AGREEMENT-NOT-FOUND))
    )
    (begin
      (asserts! (is-country-representative country-id tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (is-eq (get status proposal-data) STATUS-PROPOSED) ERR-INVALID-AGREEMENT)

      (map-set harmonization-proposals
        { proposal-id: proposal-id }
        (merge proposal-data {
          support-votes: (if support (+ (get support-votes proposal-data) u1) (get support-votes proposal-data)),
          opposition-votes: (if support (get opposition-votes proposal-data) (+ (get opposition-votes proposal-data) u1))
        })
      )

      (ok true)
    )
  )
)

(define-public (update-agreement-status (agreement-id uint) (new-status (string-ascii 15)))
  (let
    (
      (agreement-data (unwrap! (get-international-agreement agreement-id) ERR-AGREEMENT-NOT-FOUND))
    )
    (begin
      (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)

      (map-set international-agreements
        { agreement-id: agreement-id }
        (merge agreement-data {
          status: new-status,
          last-updated: block-height
        })
      )

      (ok true)
    )
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

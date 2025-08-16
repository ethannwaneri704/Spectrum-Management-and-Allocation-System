;; Interference Monitor Contract
;; Monitors spectrum usage and detects/resolves conflicts

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-REPORT (err u401))
(define-constant ERR-REPORT-NOT-FOUND (err u402))
(define-constant ERR-INVALID-COORDINATES (err u403))
(define-constant ERR-INVALID-POWER-LEVEL (err u404))
(define-constant ERR-INTERFERENCE-EXISTS (err u405))
(define-constant ERR-RESOLUTION-FAILED (err u406))
(define-constant ERR-INVALID-INPUT (err u407))
(define-constant ERR-SENSOR-NOT-FOUND (err u408))

;; Interference severity levels
(define-constant SEVERITY-LOW "LOW")
(define-constant SEVERITY-MEDIUM "MEDIUM")
(define-constant SEVERITY-HIGH "HIGH")
(define-constant SEVERITY-CRITICAL "CRITICAL")

;; Resolution status
(define-constant STATUS-DETECTED "DETECTED")
(define-constant STATUS-INVESTIGATING "INVESTIGATING")
(define-constant STATUS-RESOLVING "RESOLVING")
(define-constant STATUS-RESOLVED "RESOLVED")
(define-constant STATUS-ESCALATED "ESCALATED")

;; Sensor types
(define-constant SENSOR-TYPE-FIXED "FIXED")
(define-constant SENSOR-TYPE-MOBILE "MOBILE")
(define-constant SENSOR-TYPE-SATELLITE "SATELLITE")

;; Data Variables
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var next-report-id uint u1)
(define-data-var next-sensor-id uint u1)
(define-data-var interference-threshold uint u50) ;; dB threshold
(define-data-var auto-resolution-enabled bool true)

;; Data Maps
(define-map interference-reports
  { report-id: uint }
  {
    reporter: principal,
    affected-license: uint,
    interfering-source: (optional uint),
    frequency-range: { start: uint, end: uint },
    geographic-area: { lat: int, lon: int, radius: uint },
    interference-level: uint,
    severity: (string-ascii 10),
    detected-at: uint,
    status: (string-ascii 15),
    assigned-investigator: (optional principal),
    resolution-actions: (string-ascii 500),
    resolved-at: (optional uint),
    verification-required: bool
  }
)

(define-map monitoring-sensors
  { sensor-id: uint }
  {
    sensor-type: (string-ascii 10),
    location: { lat: int, lon: int, altitude: uint },
    frequency-coverage: { start: uint, end: uint },
    sensitivity: uint,
    operator: principal,
    installed-at: uint,
    last-calibration: uint,
    is-active: bool,
    data-quality: uint
  }
)

(define-map power-measurements
  { sensor-id: uint, timestamp: uint }
  {
    frequency: uint,
    power-level: uint,
    location: { lat: int, lon: int },
    measurement-quality: uint,
    license-id: (optional uint)
  }
)

(define-map interference-patterns
  { pattern-id: uint }
  {
    frequency-range: { start: uint, end: uint },
    geographic-pattern: (string-ascii 100),
    time-pattern: (string-ascii 50),
    typical-sources: (list 5 (string-ascii 50)),
    resolution-methods: (list 3 (string-ascii 100)),
    success-rate: uint
  }
)

(define-map resolution-actions
  { report-id: uint, action-id: uint }
  {
    action-type: (string-ascii 30),
    description: (string-ascii 200),
    implemented-by: principal,
    implemented-at: uint,
    effectiveness: uint,
    cost: uint
  }
)

(define-map geographic-zones
  { zone-id: uint }
  {
    zone-name: (string-ascii 50),
    boundaries: { lat-min: int, lat-max: int, lon-min: int, lon-max: int },
    protection-level: uint,
    monitoring-density: uint,
    special-restrictions: (string-ascii 200)
  }
)

(define-map license-monitoring
  { license-id: uint }
  {
    monitoring-sensors: (list 10 uint),
    baseline-power: uint,
    max-deviation: uint,
    alert-threshold: uint,
    last-check: uint,
    compliance-status: (string-ascii 20)
  }
)

;; Read-only functions
(define-read-only (get-interference-report (report-id uint))
  (map-get? interference-reports { report-id: report-id })
)

(define-read-only (get-monitoring-sensor (sensor-id uint))
  (map-get? monitoring-sensors { sensor-id: sensor-id })
)

(define-read-only (get-power-measurement (sensor-id uint) (timestamp uint))
  (map-get? power-measurements { sensor-id: sensor-id, timestamp: timestamp })
)

(define-read-only (get-interference-pattern (pattern-id uint))
  (map-get? interference-patterns { pattern-id: pattern-id })
)

(define-read-only (get-geographic-zone (zone-id uint))
  (map-get? geographic-zones { zone-id: zone-id })
)

(define-read-only (get-license-monitoring (license-id uint))
  (map-get? license-monitoring { license-id: license-id })
)

(define-read-only (calculate-interference-severity (interference-level uint))
  (if (< interference-level u20)
    SEVERITY-LOW
    (if (< interference-level u40)
      SEVERITY-MEDIUM
      (if (< interference-level u70)
        SEVERITY-HIGH
        SEVERITY-CRITICAL
      )
    )
  )
)

(define-read-only (is-interference-critical (report-id uint))
  (match (get-interference-report report-id)
    report-data (is-eq (get severity report-data) SEVERITY-CRITICAL)
    false
  )
)

(define-read-only (get-interference-threshold)
  (var-get interference-threshold)
)

;; Private functions
(define-private (is-authorized (caller principal))
  (is-eq caller (var-get contract-owner))
)

(define-private (is-valid-coordinates (lat int) (lon int))
  (and
    (and (>= lat -90000000) (<= lat 90000000))  ;; Latitude in micro-degrees
    (and (>= lon -180000000) (<= lon 180000000)) ;; Longitude in micro-degrees
  )
)

(define-private (is-valid-frequency (frequency uint))
  (and (> frequency u0) (< frequency u300000000)) ;; Up to 300 GHz in kHz
)

(define-private (is-valid-power-level (power uint))
  (< power u1000000) ;; Max 1MW in mW
)

(define-private (calculate-distance (lat1 int) (lon1 int) (lat2 int) (lon2 int))
  ;; Simplified distance calculation (Euclidean approximation)
  (let
    (
      (lat-diff (if (> lat1 lat2) (- lat1 lat2) (- lat2 lat1)))
      (lon-diff (if (> lon1 lon2) (- lon1 lon2) (- lon2 lon1)))
    )
    (+ (* lat-diff lat-diff) (* lon-diff lon-diff))
  )
)

;; Public functions
(define-public (register-monitoring-sensor (sensor-type (string-ascii 10))
                                          (lat int) (lon int) (altitude uint)
                                          (freq-start uint) (freq-end uint)
                                          (sensitivity uint))
  (let
    (
      (sensor-id (var-get next-sensor-id))
    )
    (begin
      (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (is-valid-coordinates lat lon) ERR-INVALID-COORDINATES)
      (asserts! (is-valid-frequency freq-start) ERR-INVALID-INPUT)
      (asserts! (is-valid-frequency freq-end) ERR-INVALID-INPUT)
      (asserts! (> freq-end freq-start) ERR-INVALID-INPUT)
      (asserts! (> sensitivity u0) ERR-INVALID-INPUT)

      (map-set monitoring-sensors
        { sensor-id: sensor-id }
        {
          sensor-type: sensor-type,
          location: { lat: lat, lon: lon, altitude: altitude },
          frequency-coverage: { start: freq-start, end: freq-end },
          sensitivity: sensitivity,
          operator: tx-sender,
          installed-at: block-height,
          last-calibration: block-height,
          is-active: true,
          data-quality: u100
        }
      )

      (var-set next-sensor-id (+ sensor-id u1))
      (ok sensor-id)
    )
  )
)

(define-public (report-interference (affected-license uint)
                                   (interfering-source (optional uint))
                                   (freq-start uint) (freq-end uint)
                                   (lat int) (lon int) (radius uint)
                                   (interference-level uint))
  (let
    (
      (report-id (var-get next-report-id))
      (severity (calculate-interference-severity interference-level))
    )
    (begin
      (asserts! (is-valid-coordinates lat lon) ERR-INVALID-COORDINATES)
      (asserts! (is-valid-frequency freq-start) ERR-INVALID-INPUT)
      (asserts! (is-valid-frequency freq-end) ERR-INVALID-INPUT)
      (asserts! (> freq-end freq-start) ERR-INVALID-INPUT)
      (asserts! (> radius u0) ERR-INVALID-INPUT)
      (asserts! (<= interference-level u100) ERR-INVALID-INPUT)

      (map-set interference-reports
        { report-id: report-id }
        {
          reporter: tx-sender,
          affected-license: affected-license,
          interfering-source: interfering-source,
          frequency-range: { start: freq-start, end: freq-end },
          geographic-area: { lat: lat, lon: lon, radius: radius },
          interference-level: interference-level,
          severity: severity,
          detected-at: block-height,
          status: STATUS-DETECTED,
          assigned-investigator: none,
          resolution-actions: "",
          resolved-at: none,
          verification-required: (is-eq severity SEVERITY-CRITICAL)
        }
      )

      (var-set next-report-id (+ report-id u1))

      ;; Auto-trigger resolution for critical interference
      (if (and (var-get auto-resolution-enabled) (is-eq severity SEVERITY-CRITICAL))
        (try! (initiate-auto-resolution report-id))
        true
      )

      (ok report-id)
    )
  )
)

(define-public (record-power-measurement (sensor-id uint)
                                        (frequency uint)
                                        (power-level uint)
                                        (lat int) (lon int)
                                        (measurement-quality uint)
                                        (license-id (optional uint)))
  (begin
    (asserts! (is-some (get-monitoring-sensor sensor-id)) ERR-SENSOR-NOT-FOUND)
    (asserts! (is-valid-frequency frequency) ERR-INVALID-INPUT)
    (asserts! (is-valid-power-level power-level) ERR-INVALID-POWER-LEVEL)
    (asserts! (is-valid-coordinates lat lon) ERR-INVALID-COORDINATES)
    (asserts! (<= measurement-quality u100) ERR-INVALID-INPUT)

    (map-set power-measurements
      { sensor-id: sensor-id, timestamp: block-height }
      {
        frequency: frequency,
        power-level: power-level,
        location: { lat: lat, lon: lon },
        measurement-quality: measurement-quality,
        license-id: license-id
      }
    )

    ;; Check for interference threshold violations
    (if (> power-level (var-get interference-threshold))
      (try! (report-interference
        (default-to u0 license-id)
        none
        frequency
        frequency
        lat
        lon
        u1000 ;; 1km radius
        (/ (* power-level u100) (var-get interference-threshold))
      ))
      true
    )

    (ok true)
  )
)

(define-public (assign-investigator (report-id uint) (investigator principal))
  (let
    (
      (report-data (unwrap! (get-interference-report report-id) ERR-REPORT-NOT-FOUND))
    )
    (begin
      (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (is-eq (get status report-data) STATUS-DETECTED) ERR-INVALID-REPORT)

      (map-set interference-reports
        { report-id: report-id }
        (merge report-data {
          status: STATUS-INVESTIGATING,
          assigned-investigator: (some investigator)
        })
      )

      (ok true)
    )
  )
)

(define-public (initiate-auto-resolution (report-id uint))
  (let
    (
      (report-data (unwrap! (get-interference-report report-id) ERR-REPORT-NOT-FOUND))
    )
    (begin
      (asserts! (or (is-authorized tx-sender) (var-get auto-resolution-enabled)) ERR-NOT-AUTHORIZED)

      ;; Implement basic auto-resolution logic
      (map-set interference-reports
        { report-id: report-id }
        (merge report-data {
          status: STATUS-RESOLVING,
          resolution-actions: "Auto-resolution initiated: Power reduction requested"
        })
      )

      ;; Record resolution action
      (map-set resolution-actions
        { report-id: report-id, action-id: u1 }
        {
          action-type: "POWER_REDUCTION",
          description: "Automated power reduction to resolve interference",
          implemented-by: tx-sender,
          implemented-at: block-height,
          effectiveness: u80,
          cost: u0
        }
      )

      (ok true)
    )
  )
)

(define-public (resolve-interference (report-id uint) (resolution-description (string-ascii 500)))
  (let
    (
      (report-data (unwrap! (get-interference-report report-id) ERR-REPORT-NOT-FOUND))
    )
    (begin
      (asserts! (or (is-authorized tx-sender) (is-eq tx-sender (default-to tx-sender (get assigned-investigator report-data)))) ERR-NOT-AUTHORIZED)

      (map-set interference-reports
        { report-id: report-id }
        (merge report-data {
          status: STATUS-RESOLVED,
          resolution-actions: resolution-description,
          resolved-at: (some block-height)
        })
      )

      (ok true)
    )
  )
)

(define-public (define-geographic-zone (zone-name (string-ascii 50))
                                      (lat-min int) (lat-max int)
                                      (lon-min int) (lon-max int)
                                      (protection-level uint)
                                      (monitoring-density uint)
                                      (restrictions (string-ascii 200)))
  (let
    (
      (zone-id (var-get next-sensor-id)) ;; Reuse counter for simplicity
    )
    (begin
      (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (is-valid-coordinates lat-min lon-min) ERR-INVALID-COORDINATES)
      (asserts! (is-valid-coordinates lat-max lon-max) ERR-INVALID-COORDINATES)
      (asserts! (> lat-max lat-min) ERR-INVALID-COORDINATES)
      (asserts! (> lon-max lon-min) ERR-INVALID-COORDINATES)
      (asserts! (<= protection-level u100) ERR-INVALID-INPUT)

      (map-set geographic-zones
        { zone-id: zone-id }
        {
          zone-name: zone-name,
          boundaries: { lat-min: lat-min, lat-max: lat-max, lon-min: lon-min, lon-max: lon-max },
          protection-level: protection-level,
          monitoring-density: monitoring-density,
          special-restrictions: restrictions
        }
      )

      (ok zone-id)
    )
  )
)

(define-public (setup-license-monitoring (license-id uint)
                                        (sensor-ids (list 10 uint))
                                        (baseline-power uint)
                                        (max-deviation uint)
                                        (alert-threshold uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-power-level baseline-power) ERR-INVALID-POWER-LEVEL)
    (asserts! (> max-deviation u0) ERR-INVALID-INPUT)
    (asserts! (> alert-threshold u0) ERR-INVALID-INPUT)

    (map-set license-monitoring
      { license-id: license-id }
      {
        monitoring-sensors: sensor-ids,
        baseline-power: baseline-power,
        max-deviation: max-deviation,
        alert-threshold: alert-threshold,
        last-check: block-height,
        compliance-status: "COMPLIANT"
      }
    )

    (ok true)
  )
)

(define-public (update-interference-threshold (new-threshold uint))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> new-threshold u0) ERR-INVALID-INPUT)
    (var-set interference-threshold new-threshold)
    (ok true)
  )
)

(define-public (toggle-auto-resolution (enabled bool))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (var-set auto-resolution-enabled enabled)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

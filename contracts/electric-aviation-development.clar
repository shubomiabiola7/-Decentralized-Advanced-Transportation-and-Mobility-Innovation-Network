;; Electric Aviation Development Contract
;; Coordinates development of electric aircraft and urban air mobility

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-PROJECT-NOT-FOUND (err u201))
(define-constant ERR-INVALID-PARAMETERS (err u202))
(define-constant ERR-INSUFFICIENT-FUNDING (err u203))
(define-constant ERR-AIRSPACE-OCCUPIED (err u204))

;; Data Variables
(define-data-var total-projects uint u0)
(define-data-var active-aircraft uint u0)
(define-data-var airspace-utilization uint u0)

;; Data Maps
(define-map aviation-projects
  { project-id: (string-ascii 50) }
  {
    developer: principal,
    aircraft-type: (string-ascii 30),
    development-stage: (string-ascii 20),
    funding-required: uint,
    funding-received: uint,
    estimated-completion: uint,
    safety-rating: uint,
    test-flights: uint
  })

(define-map aircraft-registry
  { aircraft-id: (string-ascii 50) }
  {
    project-id: (string-ascii 50),
    owner: principal,
    aircraft-model: (string-ascii 30),
    battery-capacity: uint,
    max-range: uint,
    passenger-capacity: uint,
    certification-status: (string-ascii 20),
    flight-hours: uint
  })

(define-map airspace-zones
  { zone-id: (string-ascii 50) }
  {
    altitude-min: uint,
    altitude-max: uint,
    capacity: uint,
    current-traffic: uint,
    weather-conditions: (string-ascii 20),
    restricted: bool
  })

(define-map flight-routes
  { route-id: (string-ascii 100) }
  {
    origin-vertiport: (string-ascii 50),
    destination-vertiport: (string-ascii 50),
    distance: uint,
    flight-time: uint,
    altitude: uint,
    traffic-density: uint
  })

;; Public Functions

;; Register new aviation development project
(define-public (register-project (project-id (string-ascii 50)) (aircraft-type (string-ascii 30)) (funding-required uint) (estimated-completion uint))
  (begin
    (asserts! (> funding-required u0) ERR-INVALID-PARAMETERS)
    (asserts! (> estimated-completion block-height) ERR-INVALID-PARAMETERS)
    (asserts! (is-none (map-get? aviation-projects { project-id: project-id })) ERR-PROJECT-NOT-FOUND)

    (map-set aviation-projects
      { project-id: project-id }
      {
        developer: tx-sender,
        aircraft-type: aircraft-type,
        development-stage: "concept",
        funding-required: funding-required,
        funding-received: u0,
        estimated-completion: estimated-completion,
        safety-rating: u0,
        test-flights: u0
      })

    (var-set total-projects (+ (var-get total-projects) u1))
    (ok true)))

;; Fund aviation project
(define-public (fund-project (project-id (string-ascii 50)) (amount uint))
  (let ((project-data (unwrap! (map-get? aviation-projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND)))

    (asserts! (> amount u0) ERR-INVALID-PARAMETERS)

    (map-set aviation-projects
      { project-id: project-id }
      (merge project-data {
        funding-received: (+ (get funding-received project-data) amount)
      }))

    (ok true)))

;; Register aircraft after development
(define-public (register-aircraft (aircraft-id (string-ascii 50)) (project-id (string-ascii 50)) (aircraft-model (string-ascii 30)) (battery-capacity uint) (max-range uint) (passenger-capacity uint))
  (let ((project-data (unwrap! (map-get? aviation-projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND)))

    (asserts! (> battery-capacity u0) ERR-INVALID-PARAMETERS)
    (asserts! (> max-range u0) ERR-INVALID-PARAMETERS)
    (asserts! (is-none (map-get? aircraft-registry { aircraft-id: aircraft-id })) ERR-PROJECT-NOT-FOUND)

    (map-set aircraft-registry
      { aircraft-id: aircraft-id }
      {
        project-id: project-id,
        owner: (get developer project-data),
        aircraft-model: aircraft-model,
        battery-capacity: battery-capacity,
        max-range: max-range,
        passenger-capacity: passenger-capacity,
        certification-status: "pending",
        flight-hours: u0
      })

    (var-set active-aircraft (+ (var-get active-aircraft) u1))
    (ok true)))

;; Define airspace zone
(define-public (define-airspace-zone (zone-id (string-ascii 50)) (altitude-min uint) (altitude-max uint) (capacity uint))
  (begin
    (asserts! (< altitude-min altitude-max) ERR-INVALID-PARAMETERS)
    (asserts! (> capacity u0) ERR-INVALID-PARAMETERS)

    (map-set airspace-zones
      { zone-id: zone-id }
      {
        altitude-min: altitude-min,
        altitude-max: altitude-max,
        capacity: capacity,
        current-traffic: u0,
        weather-conditions: "clear",
        restricted: false
      })

    (ok true)))

;; Create flight route
(define-public (create-flight-route (route-id (string-ascii 100)) (origin-vertiport (string-ascii 50)) (destination-vertiport (string-ascii 50)) (distance uint) (altitude uint))
  (begin
    (asserts! (> distance u0) ERR-INVALID-PARAMETERS)
    (asserts! (> altitude u0) ERR-INVALID-PARAMETERS)

    (map-set flight-routes
      { route-id: route-id }
      {
        origin-vertiport: origin-vertiport,
        destination-vertiport: destination-vertiport,
        distance: distance,
        flight-time: (/ distance u100),
        altitude: altitude,
        traffic-density: u1
      })

    (ok true)))

;; Update project development stage
(define-public (update-project-stage (project-id (string-ascii 50)) (new-stage (string-ascii 20)) (safety-rating uint))
  (let ((project-data (unwrap! (map-get? aviation-projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND)))

    (asserts! (is-eq tx-sender (get developer project-data)) ERR-NOT-AUTHORIZED)
    (asserts! (<= safety-rating u100) ERR-INVALID-PARAMETERS)

    (map-set aviation-projects
      { project-id: project-id }
      (merge project-data {
        development-stage: new-stage,
        safety-rating: safety-rating
      }))

    (ok true)))

;; Record test flight
(define-public (record-test-flight (project-id (string-ascii 50)) (aircraft-id (string-ascii 50)) (flight-duration uint))
  (let ((project-data (unwrap! (map-get? aviation-projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
        (aircraft-data (unwrap! (map-get? aircraft-registry { aircraft-id: aircraft-id }) ERR-PROJECT-NOT-FOUND)))

    (asserts! (is-eq tx-sender (get developer project-data)) ERR-NOT-AUTHORIZED)
    (asserts! (> flight-duration u0) ERR-INVALID-PARAMETERS)

    ;; Update project test flights
    (map-set aviation-projects
      { project-id: project-id }
      (merge project-data {
        test-flights: (+ (get test-flights project-data) u1)
      }))

    ;; Update aircraft flight hours
    (map-set aircraft-registry
      { aircraft-id: aircraft-id }
      (merge aircraft-data {
        flight-hours: (+ (get flight-hours aircraft-data) flight-duration)
      }))

    (ok true)))

;; Read-only Functions

(define-read-only (get-project-info (project-id (string-ascii 50)))
  (map-get? aviation-projects { project-id: project-id }))

(define-read-only (get-aircraft-info (aircraft-id (string-ascii 50)))
  (map-get? aircraft-registry { aircraft-id: aircraft-id }))

(define-read-only (get-airspace-info (zone-id (string-ascii 50)))
  (map-get? airspace-zones { zone-id: zone-id }))

(define-read-only (get-route-info (route-id (string-ascii 100)))
  (map-get? flight-routes { route-id: route-id }))

(define-read-only (get-aviation-stats)
  {
    total-projects: (var-get total-projects),
    active-aircraft: (var-get active-aircraft),
    airspace-utilization: (var-get airspace-utilization)
  })

;; Private Functions

(define-private (calculate-airspace-utilization)
  (let ((total-capacity u1000)
        (current-usage (var-get active-aircraft)))
    (if (> total-capacity u0)
      (/ (* current-usage u100) total-capacity)
      u0)))

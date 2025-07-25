;; DiagnosticChain - Medical Diagnostic Results Management
;; Version: 1.0.0

(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_TEST_NOT_FOUND (err u101))
(define-constant ERR_INVALID_LAB (err u102))
(define-constant ERR_INVALID_PATIENT (err u103))
(define-constant ERR_RESULT_EXISTS (err u104))

(define-map diagnostic-tests
  { test-id: uint }
  {
    patient-id: principal,
    ordering-physician: principal,
    lab-facility: principal,
    test-type: (string-ascii 100),
    test-code: (string-ascii 20),
    order-date: uint,
    sample-collected: uint,
    priority-level: (string-ascii 20),
    status: (string-ascii 30),
    estimated-completion: uint
  }
)

(define-map test-results
  { test-id: uint }
  {
    result-values: (string-ascii 500),
    reference-ranges: (string-ascii 300),
    abnormal-flags: (string-ascii 100),
    result-date: uint,
    technician-id: principal,
    reviewed-by: principal,
    result-hash: (buff 32),
    interpretation: (string-ascii 400),
    follow-up-required: bool
  }
)

(define-map lab-facilities
  { lab-id: principal }
  {
    facility-name: (string-ascii 100),
    license-number: (string-ascii 50),
    accreditation: (string-ascii 50),
    specialties: (string-ascii 200),
    certified-date: uint,
    is-active: bool
  }
)

(define-map patient-test-history
  { patient-id: principal, history-id: uint }
  {
    test-id: uint,
    test-date: uint,
    test-type: (string-ascii 100),
    result-summary: (string-ascii 200),
    physician-notes: (string-ascii 300)
  }
)

(define-map quality-control
  { test-id: uint }
  {
    qc-batch: (string-ascii 30),
    calibration-date: uint,
    instrument-id: (string-ascii 50),
    qc-passed: bool,
    validation-notes: (string-ascii 200)
  }
)

(define-data-var next-test-id uint u1)
(define-data-var next-history-id uint u1)
(define-constant contract-owner tx-sender)

(define-public (register-lab-facility
  (lab-id principal)
  (facility-name (string-ascii 100))
  (license-number (string-ascii 50))
  (accreditation (string-ascii 50))
  (specialties (string-ascii 200)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR_NOT_AUTHORIZED)
    (map-set lab-facilities
      { lab-id: lab-id }
      {
        facility-name: facility-name,
        license-number: license-number,
        accreditation: accreditation,
        specialties: specialties,
        certified-date: block-height,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (order-diagnostic-test
  (patient-id principal)
  (lab-facility principal)
  (test-type (string-ascii 100))
  (test-code (string-ascii 20))
  (priority-level (string-ascii 20))
  (estimated-completion uint))
  (let ((test-id (var-get next-test-id))
        (lab-data (unwrap! (map-get? lab-facilities { lab-id: lab-facility }) ERR_INVALID_LAB)))
    (asserts! (get is-active lab-data) ERR_INVALID_LAB)
    (map-set diagnostic-tests
      { test-id: test-id }
      {
        patient-id: patient-id,
        ordering-physician: tx-sender,
        lab-facility: lab-facility,
        test-type: test-type,
        test-code: test-code,
        order-date: block-height,
        sample-collected: u0,
        priority-level: priority-level,
        status: "ordered",
        estimated-completion: estimated-completion
      }
    )
    (var-set next-test-id (+ test-id u1))
    (ok test-id)
  )
)

(define-public (collect-sample (test-id uint))
  (let ((test-data (unwrap! (map-get? diagnostic-tests { test-id: test-id }) ERR_TEST_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get lab-facility test-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status test-data) "ordered") ERR_NOT_AUTHORIZED)
    (map-set diagnostic-tests
      { test-id: test-id }
      (merge test-data {
        sample-collected: block-height,
        status: "sample-collected"
      })
    )
    (ok true)
  )
)

(define-public (submit-test-results
  (test-id uint)
  (result-values (string-ascii 500))
  (reference-ranges (string-ascii 300))
  (abnormal-flags (string-ascii 100))
  (technician-id principal)
  (result-hash (buff 32))
  (interpretation (string-ascii 400))
  (follow-up-required bool))
  (let ((test-data (unwrap! (map-get? diagnostic-tests { test-id: test-id }) ERR_TEST_NOT_FOUND))
        (existing-result (map-get? test-results { test-id: test-id })))
    (asserts! (is-eq tx-sender (get lab-facility test-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status test-data) "sample-collected") ERR_NOT_AUTHORIZED)
    (asserts! (is-none existing-result) ERR_RESULT_EXISTS)
    (map-set test-results
      { test-id: test-id }
      {
        result-values: result-values,
        reference-ranges: reference-ranges,
        abnormal-flags: abnormal-flags,
        result-date: block-height,
        technician-id: technician-id,
        reviewed-by: tx-sender,
        result-hash: result-hash,
        interpretation: interpretation,
        follow-up-required: follow-up-required
      }
    )
    (map-set diagnostic-tests
      { test-id: test-id }
      (merge test-data { status: "completed" })
    )
    (unwrap-panic (add-to-patient-history 
      (get patient-id test-data) 
      test-id 
      (get test-type test-data)
      abnormal-flags))
    (ok true)
  )
)

(define-public (add-quality-control
  (test-id uint)
  (qc-batch (string-ascii 30))
  (calibration-date uint)
  (instrument-id (string-ascii 50))
  (qc-passed bool)
  (validation-notes (string-ascii 200)))
  (let ((test-data (unwrap! (map-get? diagnostic-tests { test-id: test-id }) ERR_TEST_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get lab-facility test-data)) ERR_NOT_AUTHORIZED)
    (map-set quality-control
      { test-id: test-id }
      {
        qc-batch: qc-batch,
        calibration-date: calibration-date,
        instrument-id: instrument-id,
        qc-passed: qc-passed,
        validation-notes: validation-notes
      }
    )
    (ok true)
  )
)

(define-public (approve-results (test-id uint))
  (let ((test-data (unwrap! (map-get? diagnostic-tests { test-id: test-id }) ERR_TEST_NOT_FOUND))
        (result-data (unwrap! (map-get? test-results { test-id: test-id }) ERR_TEST_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get ordering-physician test-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status test-data) "completed") ERR_NOT_AUTHORIZED)
    (map-set diagnostic-tests
      { test-id: test-id }
      (merge test-data { status: "approved" })
    )
    (ok true)
  )
)

(define-private (add-to-patient-history
  (patient-id principal)
  (test-id uint)
  (test-type (string-ascii 100))
  (result-summary (string-ascii 200)))
  (let ((history-id (var-get next-history-id)))
    (map-set patient-test-history
      { patient-id: patient-id, history-id: history-id }
      {
        test-id: test-id,
        test-date: block-height,
        test-type: test-type,
        result-summary: result-summary,
        physician-notes: ""
      }
    )
    (var-set next-history-id (+ history-id u1))
    (ok history-id)
  )
)
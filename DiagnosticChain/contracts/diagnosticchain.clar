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
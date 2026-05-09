;;;; cl-csv — CSV reader and writer for Common Lisp
;;;;
;;;; Conforms to:
;;;;   RFC 4180  — Common Format and MIME Type for Comma-Separated Values
;;;;   RFC 7111  — URI Fragment Identifiers for the text/csv Media Type
;;;;   RFC 2046  — MIME Part Two: Media Types (defines text/* line-end rules)
;;;;   RFC 6838  — Media Type Specifications and Registration Procedures
;;;;
;;;; The MIME type for CSV files is "text/csv" (RFC 4180 §3).
;;;; Recognised parameters:  charset (default US-ASCII per RFC 2046 §4.1.2)
;;;;                          header  ("present" | "absent", RFC 4180 §3)

(defpackage :cl-csv
  (:use :cl)
  (:export
   ;; Dynamic variables
   #:*separator*
   #:*quote*
   #:*newline*
   #:*always-quote*

   ;; Conditions
   #:csv-error
   #:csv-parse-error
   #:csv-parse-error-message
   #:csv-parse-error-line
   #:csv-parse-error-column

   ;; Reader
   #:read-csv-row
   #:read-csv
   #:csv-parser
   #:csv-parser-begin-document
   #:csv-parser-end-document
   #:csv-parser-header
   #:csv-parser-line
   #:csv-parser-result
   #:parse-csv

   ;; Writer
   #:write-csv-field
   #:write-csv-row
   #:write-csv

   ;; RFC 7111 fragment-identifier support
   #:parse-fragment
   #:select-by-fragment))

(in-package :cl-csv)

(in-package :cl-csv)

(defclass csv-parser ()
  ()
  (:documentation "Base class for event-driven CSV parser implementations."))

(defgeneric csv-parser-begin-document (parser)
  (:documentation "Handle the start of a CSV document."))

(defgeneric csv-parser-end-document (parser)
  (:documentation "Handle the end of a CSV document."))

(defgeneric csv-parser-header (parser row)
  (:documentation "Handle a CSV header row."))

(defgeneric csv-parser-line (parser row)
  (:documentation "Handle a CSV data row."))

(defgeneric csv-parser-result (parser)
  (:documentation "Return the final result produced by PARSER."))


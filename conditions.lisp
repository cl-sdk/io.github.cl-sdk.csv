(in-package :io.github.cl-sdk.ini)

(define-condition csv-error (error)
  ()
  (:documentation "Base condition for all cl-csv errors."))

(define-condition csv-parse-error (csv-error)
  ((message :initarg :message :reader csv-parse-error-message)
   (line    :initarg :line    :reader csv-parse-error-line    :initform nil)
   (column  :initarg :column  :reader csv-parse-error-column  :initform nil))
  (:report
   (lambda (c s)
     (format s "CSV parse error~@[ at line ~A~]~@[, column ~A~]: ~A"
(csv-parse-error-line    c)
	     (csv-parse-error-column  c)
	     (csv-parse-error-message c))))
  (:documentation "Signalled when malformed CSV input is encountered."))

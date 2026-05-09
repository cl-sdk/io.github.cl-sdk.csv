(defpackage :cl-csv.cli
  (:use :cl)
  (:import-from :cl-csv #:read-csv)
  (:export #:run #:main))

(in-package :cl-csv.cli)

(defun usage (stream)
  (format stream "Usage: cl-csv-dump [CSV-PATH|-]~%")
  (format stream "Reads CSV and prints rows as an s-expression.~%")
  (format stream "If no path (or '-') is provided, reads from stdin.~%"))

(defun read-rows-from-arg (arg stdin)
  (cond
    ((or (null arg) (string= arg "-"))
     (read-csv stdin))
    (t
     (handler-case
         (read-csv (pathname arg))
       (file-error ()
         (error "Cannot read file ~S." arg))))))

(defun run (argv &key
                   (stdin *standard-input*)
                   (stdout *standard-output*)
                   (stderr *error-output*))
  "Run the CLI with ARGV (excluding program name). Returns process exit code."
  (cond
    ((member (first argv) '("--help" "-h") :test #'string=)
     (usage stdout)
     0)
    ((> (length argv) 1)
     (usage stderr)
     2)
    (t
     (handler-case
         (let* ((arg (first argv))
                (rows (read-rows-from-arg arg stdin))
                (*print-readably* t))
           (prin1 rows stdout)
           (terpri stdout)
           0)
       (error (e)
         (format stderr "cl-csv-dump: ~A~%" e)
         1)))))

(defun main ()
  (let ((exit-code (run (uiop:command-line-arguments))))
    (uiop:quit exit-code)))

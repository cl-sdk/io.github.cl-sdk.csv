(defpackage :cl-csv.cli
  (:use :cl)
  (:export #:run #:main))

(in-package :cl-csv.cli)

(defun usage (stream)
  (format stream "Usage: cl-csv-dump [--no-header] [CSV-PATH|-]~%")
  (format stream "Reads CSV and prints rows as an s-expression.~%")
  (format stream "If no path (or '-') is provided, reads from stdin.~%")
  (format stream "~%")
  (format stream "Options:~%")
  (format stream "  --no-header  treat the file as having no header row~%"))

(defun read-rows-from-arg (arg stdin &key has-header)
  (cond
    ((or (null arg) (string= arg "-"))
     (io.github.cl-sdk.ini:parse-csv stdin :has-header has-header))
    (t
     (handler-case
	 (with-open-file (s (pathname arg))
	  (io.github.cl-sdk.ini:parse-csv s :has-header has-header))
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
    (t
     (let* ((no-header-p (member "--no-header" argv :test #'string=))
	    (remaining   (remove "--no-header" argv :test #'string=))
	    (has-header  (not no-header-p)))
       (cond
	 ((> (length remaining) 1)
	  (usage stderr)
	  2)
	 (t
	  (handler-case
	      (let* ((arg (first remaining))
		     (rows (read-rows-from-arg arg stdin :has-header has-header))
		     (*print-readably* t))
		(prin1 rows stdout)
		(terpri stdout)
		0)
	    (error (e)
	      (format stderr "cl-csv-dump: ~A~%" e)
	      1))))))))

(defun main ()
  (let ((exit-code (run (uiop:command-line-arguments))))
    (uiop:quit exit-code)))

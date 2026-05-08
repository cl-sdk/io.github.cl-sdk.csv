(defun cl-csv-readme-text ()
  (let ((readme (merge-pathnames #P"README.md" *load-truename*)))
    (if (probe-file readme)
        (uiop:read-file-string readme)
        "CSV reader and writer for Common Lisp.")))

(asdf:defsystem :cl-csv
  :long-name "cl-csv CSV library"
  :description "CSV reader and writer for Common Lisp"
  :long-description #.(cl-csv-readme-text)
  :author "cl-sdk"
  :maintainer "cl-sdk"
  :license "Unlicense"
  :homepage "https://github.com/cl-sdk/cl-csv"
  :bug-tracker "https://github.com/cl-sdk/cl-csv/issues"
  :source-control (:git "https://github.com/cl-sdk/cl-csv.git")
  :serial t
  :components ((:file "cl-csv"))
  :in-order-to ((test-op (test-op :cl-csv.test))))

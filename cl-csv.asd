(asdf:defsystem :cl-csv
  :long-name "CSV reader and writer for Common Lisp"
  :description "CSV reader and writer for Common Lisp"
  :long-description
  #.(uiop:read-file-string
     (merge-pathnames #P"README.md" *load-truename*))
  :author "cl-sdk"
  :maintainer "cl-sdk"
  :license "Unlicense"
  :homepage "https://github.com/cl-sdk/cl-csv"
  :bug-tracker "https://github.com/cl-sdk/cl-csv/issues"
  :source-control (:git "https://github.com/cl-sdk/cl-csv.git")
  :serial t
  :components ((:file "cl-csv"))
  :in-order-to ((test-op (test-op :cl-csv.test))))

(asdf:defsystem :cl-csv
  :description "CSV reader and writer for Common Lisp"
  :serial t
  :components ((:file "cl-csv"))
  :in-order-to ((test-op (test-op :cl-csv.test))))

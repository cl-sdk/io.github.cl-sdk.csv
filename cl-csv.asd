(asdf:defsystem #:cl-csv
  :long-name "cl-csv CSV library"
  :description "CSV reader and writer for Common Lisp"
  :long-description
  "CSV reader and writer for Common Lisp with RFC 4180 parsing and writing,
RFC 7111 fragment-identifier support, configurable separator/quote/newline
handling, and APIs for streams, strings, and pathnames."
  :author "cl-sdk"
  :maintainer "cl-sdk"
  :license "Unlicense"
  :homepage "https://github.com/cl-sdk/cl-csv"
  :bug-tracker "https://github.com/cl-sdk/cl-csv/issues"
  :source-control (:git "https://github.com/cl-sdk/cl-csv.git")
  :serial t
  :components ((:file "cl-csv")))

(asdf:defsystem #:cl-csv.cli
  :long-name "cl-csv CLI"
  :description "Standalone CLI to read CSV and print s-expressions"
  :author "cl-sdk"
  :maintainer "cl-sdk"
  :license "Unlicense"
  :depends-on (:cl-csv)
  :serial t
  :components ((:file "cl-csv-cli"))
  :build-operation "program-op"
  :build-pathname "cl-csv-dump"
  :entry-point "cl-csv.cli:main")

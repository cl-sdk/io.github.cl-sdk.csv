(asdf:defsystem #:cl-csv.cli
  :long-name "cl-csv CLI"
  :description "Standalone CLI to read CSV and print s-expressions"
  :author "cl-sdk"
  :maintainer "cl-sdk"
  :license "Unlicense"
  :depends-on (:cl-csv :uiop)
  :serial t
  :components ((:file "cl-csv-cli"))
  :build-operation "program-op"
  :build-pathname "cl-csv-dump"
  :entry-point "cl-csv.cli:main")

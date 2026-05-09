(asdf:defsystem #:io.github.cl-sdk.ini.test
  :long-name "io.github.cl-sdk.ini.test"
  :description "Tests for io.github.cl-sdk.ini using the FiveAM test framework"
  :long-description "Regression tests for the io.github.cl-sdk.ini ASDF system."
  :author "cl-sdk"
  :maintainer "cl-sdk"
  :license "Unlicense"
  :homepage "https://github.com/cl-sdk/cl-csv"
  :bug-tracker "https://github.com/cl-sdk/cl-csv/issues"
  :source-control (:git "https://github.com/cl-sdk/cl-csv.git")
  :serial t
  :depends-on (:io.github.cl-sdk.ini :fiveam)
  :components ((:file "t/test")))

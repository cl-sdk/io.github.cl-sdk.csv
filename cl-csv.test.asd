(asdf:defsystem :cl-csv.test
  :description "Tests for cl-csv using the Parachute test framework"
  :author "cl-sdk"
  :license "Unlicense"
  :serial t
  :depends-on (:cl-csv :parachute)
  :components ((:file "t/test"))
  :perform (test-op (op c)
             (uiop:symbol-call :parachute :test :cl-csv.test)))

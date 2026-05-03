(asdf:defsystem :cl-csv.test
  :description "Tests for cl-csv using the Parachute test framework"
  :author "cl-sdk"
  :license "Unlicense"
  :serial t
  :defsystem-depends-on ()
  :depends-on (:cl-csv :parachute)
  :components ((:file "t/test"))
  :perform (test-op (op c)
             (uiop:symbol-call :parachute :test :cl-csv.test
                               :report (find-symbol "PLAIN" :parachute))))

;;; Register vendored libraries so that parachute and its dependencies
;;; are found when this .asd is loaded from the project root.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (let ((vendor-dir (merge-pathnames "vendor/"
                                     (asdf:system-source-directory
                                      (asdf:find-system :cl-csv.test nil)))))
    (when (and vendor-dir (probe-file vendor-dir))
      (dolist (lib (uiop:subdirectories vendor-dir))
        (pushnew lib asdf:*central-registry* :test #'equal)))))

(push *default-pathname-defaults* ql:*local-project-directories*)

(setf asdf/source-registry::*source-registry-file* #P"./.qlot/")

(asdf:initialize-source-registry)

(ql:quickload :io.github.cl-sdk.ini.test)

(unless (fiveam:run-all-tests)
  (uiop:quit -1))

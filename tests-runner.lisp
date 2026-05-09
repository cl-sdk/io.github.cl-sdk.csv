(push *default-pathname-defaults* ql:*local-project-directories*)

(setf asdf/source-registry::*source-registry-file* #P"./.qlot/")

(asdf:initialize-source-registry)

(ql:quickload :cl-csv.test)

(fiveam:run! 'cl-csv.test::cl-csv.test)

(defpackage #:trivial-custom-debugger
  (:use #:cl)
  (:export #:with-debugger))

(in-package #:trivial-custom-debugger)

(defmacro with-debugger ((hook) &body body)
  "Evaluate BODY with *DEBUGGER-HOOK* bound to HOOK."
  `(let ((*debugger-hook*
          (lambda (condition previous-hook)
            (declare (ignore previous-hook))
            (funcall ,hook condition nil))))
     ,@body))

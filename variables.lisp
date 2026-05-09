(in-package :io.github.cl-sdk.ini)

(defparameter *separator* #\,
  "Field-separator character used by the reader and writer.
RFC 4180 §2 specifies comma; other common choices are #\\Tab (TSV).")

(defparameter *quote* #\"
  "Quoting character used to wrap fields that contain special characters.
RFC 4180 §2 specifies DQUOTE.")

(defparameter *newline* (coerce '(#\Return #\Newline) 'string)
  "Line-ending string appended after each row during writing.
RFC 4180 §2 rule 1 requires CRLF; set to \"\\n\" for Unix-only output.")

(defparameter *always-quote* nil
  "When non-NIL every field is quoted on output, regardless of content.")


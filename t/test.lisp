;;;; Tests for cl-csv
;;;;
;;;; Test cases are drawn directly from the normative examples in:
;;;;   RFC 4180 §2  — CSV format rules and examples
;;;;   RFC 7111 §3  — URI fragment identifier examples for text/csv

(defpackage :cl-csv.test
  (:use :cl :parachute))

(in-package :cl-csv.test)

;;; -----------------------------------------------------------------------
;;; Helpers
;;; -----------------------------------------------------------------------

(defun join-with-crlf (strings &key trailing-crlf)
  "Concatenate STRINGS inserting CRLF between them.
When TRAILING-CRLF is non-NIL, append a final CRLF after the last string."
  (let ((crlf (coerce '(#\Return #\Newline) 'string)))
    (with-output-to-string (s)
      (loop for (str . rest) on strings
            do (write-string str s)
               (when (or rest trailing-crlf)
                 (write-string crlf s))))))

(defun crlf (&rest strings)
  "Join STRINGS with CRLF and append a trailing CRLF (RFC 4180 §2 rule 2)."
  (join-with-crlf strings :trailing-crlf t))

(defun with-crlf (&rest strings)
  "Join STRINGS with CRLF separators, no trailing CRLF."
  (join-with-crlf strings :trailing-crlf nil))


;;; -----------------------------------------------------------------------
;;; RFC 4180 §2  Reader Tests
;;;
;;; The examples below use the exact text from RFC 4180.
;;; -----------------------------------------------------------------------

(define-test rfc-4180-reader
  :description "RFC 4180 §2 reader conformance")

;;; RFC 4180 §2 Rule 1:
;;; "Each record is located on a separate line, delimited by a line break
;;; (CRLF)."
;;;   field_name,field_name,field_name CRLF
;;;   aaa,bbb,ccc CRLF
;;;   zzz,yyy,xxx CRLF
(define-test rfc-4180/rule-1-crlf
  :parent rfc-4180-reader
  :description "Each record is on a separate line delimited by CRLF"
  (let ((input (crlf "aaa,bbb,ccc" "zzz,yyy,xxx")))
    (is equal
        '(("aaa" "bbb" "ccc") ("zzz" "yyy" "xxx"))
        (cl-csv:read-csv input))))

;;; RFC 4180 §2 Rule 2:
;;; "The last record in the file may or may not have an ending line break."
(define-test rfc-4180/rule-2-no-trailing-crlf
  :parent rfc-4180-reader
  :description "Last record may omit the trailing line break"
  (is equal
      '(("aaa" "bbb" "ccc") ("zzz" "yyy" "xxx"))
      (cl-csv:read-csv (with-crlf "aaa,bbb,ccc" "zzz,yyy,xxx"))))

;;; RFC 4180 §2 Rule 3:
;;; "There may be an optional header record appearing as the first line of
;;; the file with the same format as normal record lines."
;;;   field_name,field_name,field_name CRLF
;;;   aaa,bbb,ccc CRLF
;;;   zzz,yyy,xxx CRLF
(define-test rfc-4180/rule-3-optional-header
  :parent rfc-4180-reader
  :description "Optional header record has the same format as data records"
  (let* ((input (crlf "field_name,field_name,field_name"
                      "aaa,bbb,ccc"
                      "zzz,yyy,xxx"))
         (rows (cl-csv:read-csv input)))
    (is equal '("field_name" "field_name" "field_name") (first rows))
    (is equal '("aaa" "bbb" "ccc") (second rows))
    (is equal '("zzz" "yyy" "xxx") (third rows))
    (is = 3 (length rows))))

;;; RFC 4180 §2 Rule 4:
;;; "Within the header and each record, there may be one or more fields,
;;; separated by commas."
;;;   aaa,bbb,ccc
(define-test rfc-4180/rule-4-comma-separator
  :parent rfc-4180-reader
  :description "Fields are separated by commas"
  (is equal '(("aaa" "bbb" "ccc")) (cl-csv:read-csv "aaa,bbb,ccc")))

;;; RFC 4180 §2 Rule 5:
;;; "Each field may or may not be enclosed in double quotes."
;;;   "aaa","bbb","ccc" CRLF
;;;   zzz,yyy,xxx
(define-test rfc-4180/rule-5-optional-quoting
  :parent rfc-4180-reader
  :description "Fields may optionally be enclosed in double quotes"
  (let ((input (with-crlf "\"aaa\",\"bbb\",\"ccc\"" "zzz,yyy,xxx")))
    (is equal
        '(("aaa" "bbb" "ccc") ("zzz" "yyy" "xxx"))
        (cl-csv:read-csv input))))

;;; RFC 4180 §2 Rule 6:
;;; "Fields containing line breaks (CRLF), double quotes, and commas
;;; should be enclosed in double-quotes."
;;;   "aaa","b CRLF
;;;   bb","ccc" CRLF
;;;   zzz,yyy,xxx
(define-test rfc-4180/rule-6-quoted-embedded-crlf
  :parent rfc-4180-reader
  :description "Fields containing CRLF must be enclosed in double-quotes"
  (let ((input (concatenate 'string
                             "\"aaa\",\"b" (string #\Return) (string #\Newline)
                             "bb\",\"ccc\"" (string #\Return) (string #\Newline)
                             "zzz,yyy,xxx")))
    (is equal
        (list (list "aaa"
                    (concatenate 'string "b" (string #\Return) (string #\Newline) "bb")
                    "ccc")
              (list "zzz" "yyy" "xxx"))
        (cl-csv:read-csv input))))

;;; RFC 4180 §2 Rule 7:
;;; "If double-quotes are used to enclose fields, then a double-quote
;;; appearing inside a field must be escaped by preceding it with another
;;; double quote."
;;;   "aaa","b""bb","ccc"
(define-test rfc-4180/rule-7-escaped-double-quote
  :parent rfc-4180-reader
  :description "Double-quote inside a quoted field is escaped by doubling"
  (is equal
      '(("aaa" "b\"bb" "ccc"))
      (cl-csv:read-csv "\"aaa\",\"b\"\"bb\",\"ccc\"")))

;;; Additional reader edge cases derived from the RFC grammar

(define-test rfc-4180/empty-fields
  :parent rfc-4180-reader
  :description "Empty fields (leading, middle, trailing separator)"
  (is equal '(("" "b" "")) (cl-csv:read-csv ",b,")))

(define-test rfc-4180/single-field
  :parent rfc-4180-reader
  :description "Single field with no separators"
  (is equal '(("hello")) (cl-csv:read-csv "hello")))

(define-test rfc-4180/empty-quoted-field
  :parent rfc-4180-reader
  :description "An empty quoted field reads as empty string"
  (is equal '(("" "b")) (cl-csv:read-csv "\"\",b")))

(define-test rfc-4180/bare-lf-line-ending
  :parent rfc-4180-reader
  :description "Bare LF is accepted as a line ending (common Unix variant)"
  (is equal
      '(("a" "b") ("c" "d"))
      (cl-csv:read-csv (format nil "a,b~%c,d"))))

(define-test rfc-4180/skip-empty-lines
  :parent rfc-4180-reader
  :description "skip-empty-lines option removes blank rows"
  (is equal
      '(("a" "b") ("c" "d"))
      (cl-csv:read-csv (format nil "a,b~%~%c,d")
                       :skip-empty-lines t)))


;;; -----------------------------------------------------------------------
;;; RFC 4180 §2  Writer Tests
;;; -----------------------------------------------------------------------

(define-test rfc-4180-writer
  :description "RFC 4180 §2 writer conformance")

;;; RFC 4180 §2 Rule 1: rows separated by CRLF
(define-test rfc-4180/write-crlf-terminator
  :parent rfc-4180-writer
  :description "Each row is terminated by CRLF"
  (let ((output (cl-csv:write-csv '(("aaa" "bbb") ("zzz" "yyy")) nil)))
    (true (search (coerce '(#\Return #\Newline) 'string) output))))

;;; RFC 4180 §2 Rule 7: comma in a field causes quoting
(define-test rfc-4180/write-quote-comma
  :parent rfc-4180-writer
  :description "A field containing a comma is enclosed in double quotes"
  (let ((output (cl-csv:write-csv '(("hello, world" "42")) nil)))
    (true (search "\"hello, world\"" output))))

;;; RFC 4180 §2 Rule 7: double-quote inside a field is escaped by doubling
(define-test rfc-4180/write-escape-quote
  :parent rfc-4180-writer
  :description "A double-quote inside a field is escaped by doubling"
  (let ((output (cl-csv:write-csv '(("say \"hi\"")) nil)))
    (true (search "\"say \"\"hi\"\"\"" output))))

;;; RFC 4180 §2 Rule 7: embedded newline causes quoting
(define-test rfc-4180/write-quote-newline
  :parent rfc-4180-writer
  :description "A field containing a newline is enclosed in double quotes"
  (let ((output (cl-csv:write-csv (list (list (format nil "line1~%line2"))) nil)))
    (true (char= #\" (char output 0)))))

;;; Round-trip: read(write(data)) = data
(define-test rfc-4180/round-trip
  :parent rfc-4180-writer
  :description "write-csv followed by read-csv is a round-trip identity"
  (let ((data '(("field_name" "field_name" "field_name")
                ("aaa" "bbb" "ccc")
                ("zzz" "yyy" "xxx"))))
    (is equal data (cl-csv:read-csv (cl-csv:write-csv data nil)))))

;;; always-quote option
(define-test rfc-4180/write-always-quote
  :parent rfc-4180-writer
  :description "always-quote wraps every field regardless of content"
  (let ((output (cl-csv:write-csv '(("a" "b")) nil :always-quote t)))
    (true (search "\"a\"" output))
    (true (search "\"b\"" output))))

;;; Custom separator
(define-test rfc-4180/write-custom-separator
  :parent rfc-4180-writer
  :description "Custom separator is used for output"
  (let ((output (cl-csv:write-csv '(("a" "b" "c")) nil :separator #\Tab)))
    (true (find #\Tab output))
    (false (find #\, output))))

;;; write-csv returns string when output is nil
(define-test rfc-4180/write-to-string
  :parent rfc-4180-writer
  :description "write-csv with output=nil returns a string"
  (of-type string (cl-csv:write-csv '(("a" "b")) nil)))

;;; Custom separator in reader
(define-test rfc-4180/read-custom-separator
  :parent rfc-4180-reader
  :description "Custom separator is respected by the reader"
  (is equal '(("a" "b" "c"))
      (cl-csv:read-csv (format nil "a~Cb~Cc" #\Tab #\Tab)
                       :separator #\Tab)))


;;; -----------------------------------------------------------------------
;;; RFC 7111 §3  Fragment Identifier Tests
;;;
;;; Fragment selector examples are from RFC 7111 §3 and its sub-sections.
;;; -----------------------------------------------------------------------

(define-test rfc-7111-fragment
  :description "RFC 7111 §3 URI fragment identifier conformance")

;;; RFC 7111 §3: "row=" selector
;;; "row=5" selects the 5th data row (1-based)
(define-test rfc-7111/row-single
  :parent rfc-7111-fragment
  :description "row=N selects the Nth data row (RFC 7111 §3.1)"
  (let ((table '(("r1c1" "r1c2") ("r2c1" "r2c2") ("r3c1" "r3c2"))))
    (is equal '(("r1c1" "r1c2")) (cl-csv:select-by-fragment table "row=1"))
    (is equal '(("r2c1" "r2c2")) (cl-csv:select-by-fragment table "row=2"))))

;;; RFC 7111 §3.1: "row=5-7" selects rows 5 through 7 inclusive
(define-test rfc-7111/row-range
  :parent rfc-7111-fragment
  :description "row=M-N selects rows M through N inclusive (RFC 7111 §3.1)"
  (let ((table '(("r1") ("r2") ("r3") ("r4") ("r5"))))
    (is equal '(("r2") ("r3") ("r4")) (cl-csv:select-by-fragment table "row=2-4"))))

;;; RFC 7111 §3.1: open-ended range "row=3-"
(define-test rfc-7111/row-open-end-range
  :parent rfc-7111-fragment
  :description "row=N- selects rows N through the last row (RFC 7111 §3.1)"
  (let ((table '(("r1") ("r2") ("r3") ("r4"))))
    (is equal '(("r3") ("r4")) (cl-csv:select-by-fragment table "row=3-"))))

;;; RFC 7111 §3.1: "row=5,7" selects rows 5 and 7 (not 6)
(define-test rfc-7111/row-list
  :parent rfc-7111-fragment
  :description "row=M,N selects rows M and N (RFC 7111 §3.1)"
  (let ((table '(("r1") ("r2") ("r3") ("r4") ("r5"))))
    (is equal '(("r1") ("r3") ("r5"))
        (cl-csv:select-by-fragment table "row=1,3,5"))))

;;; RFC 7111 §3: "col=" selector
;;; "col=2" selects the 2nd column of every row
(define-test rfc-7111/col-single
  :parent rfc-7111-fragment
  :description "col=N selects the Nth column of every row (RFC 7111 §3.2)"
  (let ((table '(("a" "b" "c") ("1" "2" "3"))))
    (is equal '(("b") ("2")) (cl-csv:select-by-fragment table "col=2"))))

;;; RFC 7111 §3.2: "col=2-4" selects columns 2 through 4
(define-test rfc-7111/col-range
  :parent rfc-7111-fragment
  :description "col=M-N selects columns M through N (RFC 7111 §3.2)"
  (let ((table '(("a" "b" "c" "d" "e") ("1" "2" "3" "4" "5"))))
    (is equal '(("b" "c" "d") ("2" "3" "4"))
        (cl-csv:select-by-fragment table "col=2-4"))))

;;; RFC 7111 §3: "cell=" selector
;;; "cell=4-1" selects cell at row 4, column 1
(define-test rfc-7111/cell-single
  :parent rfc-7111-fragment
  :description "cell=R-C selects cell at row R column C (RFC 7111 §3.3)"
  (let ((table '(("a" "b" "c")
                 ("d" "e" "f")
                 ("g" "h" "i"))))
    ;; cell=2-3 → row 2, col 3 → "f"; other cells masked with ""
    (is equal '(("" "" "f"))
        (cl-csv:select-by-fragment table "cell=2-3"))))

;;; RFC 7111 §3.3: cell=*-2 selects all rows, column 2
(define-test rfc-7111/cell-wildcard-row
  :parent rfc-7111-fragment
  :description "cell=*-C selects column C in all rows (RFC 7111 §3.3)"
  (let ((table '(("a" "b" "c") ("1" "2" "3") ("x" "y" "z"))))
    (is equal '(("" "b" "") ("" "2" "") ("" "y" ""))
        (cl-csv:select-by-fragment table "cell=*-2"))))

;;; RFC 7111 §3.3: cell=R-* selects an entire row
(define-test rfc-7111/cell-wildcard-col
  :parent rfc-7111-fragment
  :description "cell=R-* selects all columns of row R (RFC 7111 §3.3)"
  (let ((table '(("a" "b") ("c" "d") ("e" "f"))))
    (is equal '(("c" "d"))
        (cl-csv:select-by-fragment table "cell=2-*"))))

;;; RFC 7111 §3: multiple cell pairs
;;; "cell=3-2,5-4" selects two specific cells
(define-test rfc-7111/cell-multiple-pairs
  :parent rfc-7111-fragment
  :description "cell=R1-C1,R2-C2 selects two cells (RFC 7111 §3.3)"
  (let ((table '(("a" "b" "c" "d")
                 ("e" "f" "g" "h")
                 ("i" "j" "k" "l")
                 ("m" "n" "o" "p")
                 ("q" "r" "s" "t"))))
    ;; cell=1-2,3-4 → (row1,col2)="b" and (row3,col4)="l"
    (is equal '(("" "b" "" "")
                ("" "" "" "l"))
        (cl-csv:select-by-fragment table "cell=1-2,3-4"))))

;;; RFC 7111 §2.1: include-header option
;;; Header row is not counted in the 1-based row numbering.
(define-test rfc-7111/include-header
  :parent rfc-7111-fragment
  :description "include-header: header row is exempt from row numbering"
  (let ((table '(("name" "age" "city")
                 ("Alice" "30" "NY")
                 ("Bob"   "25" "LA")
                 ("Carol" "35" "SF"))))
    (let ((result (cl-csv:select-by-fragment table "row=1,3" :include-header t)))
      (is equal '("name" "age" "city") (first result))
      (is equal '("Alice" "30" "NY")   (second result))
      (is equal '("Carol" "35" "SF")   (third result))
      (is = 3 (length result)))))

;;; RFC 7111 §2: multiple selectors separated by ";"
(define-test rfc-7111/multiple-selectors
  :parent rfc-7111-fragment
  :description "Semicolon separates multiple selectors (RFC 7111 §2)"
  (let ((r (cl-csv:parse-fragment "row=1;col=2")))
    (is = 2 (length r))
    (is eq :row (getf (first r) :type))
    (is eq :col (getf (second r) :type))))

;;; RFC 7111 §2: wildcard * in row/col position
(define-test rfc-7111/wildcard-star
  :parent rfc-7111-fragment
  :description "\"*\" in a row selector matches all rows (RFC 7111 §2)"
  (let ((r (cl-csv:parse-fragment "row=*")))
    (is equal (cons 1 nil) (first (getf (first r) :positions)))))

;;; RFC 7111 §2: open-ended range "5-" means row 5 to the end
(define-test rfc-7111/open-ended-range
  :parent rfc-7111-fragment
  :description "N- is an open-ended range (RFC 7111 §2)"
  (let ((r (cl-csv:parse-fragment "row=3-")))
    (is equal (cons 3 nil) (first (getf (first r) :positions)))))

;;; RFC 7111 §2: leading-dash range "-7" means 1 to 7
(define-test rfc-7111/leading-dash-range
  :parent rfc-7111-fragment
  :description "\"-N\" range means rows 1 through N (RFC 7111 §2)"
  (let ((r (cl-csv:parse-fragment "row=-3")))
    (is equal (cons 1 3) (first (getf (first r) :positions)))))


;;; -----------------------------------------------------------------------
;;; Error / condition tests
;;; -----------------------------------------------------------------------

(define-test csv-conditions
  :description "csv-error and csv-parse-error conditions")

(define-test csv-conditions/parse-error-on-bad-fragment
  :parent csv-conditions
  :description "An unknown selector keyword signals csv-parse-error"
  (fail (cl-csv:parse-fragment "unknown=1") cl-csv:csv-parse-error))

(define-test csv-conditions/parse-error-message
  :parent csv-conditions
  :description "csv-parse-error carries a human-readable message"
  (handler-case (cl-csv:parse-fragment "bad=selector")
    (cl-csv:csv-parse-error (c)
      (of-type string (cl-csv:csv-parse-error-message c)))))

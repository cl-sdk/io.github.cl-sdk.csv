;;;; Tests for cl-csv
;;;;
;;;; Test cases are drawn directly from the normative examples in:
;;;;   RFC 4180 §2  — CSV format rules and examples
;;;;   RFC 7111 §3  — URI fragment identifier examples for text/csv

(defpackage :cl-csv.test
  (:use :cl :fiveam))

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
;;; Top-level suite
;;; -----------------------------------------------------------------------

(def-suite cl-csv.test
  :description "cl-csv test suite")


;;; -----------------------------------------------------------------------
;;; RFC 4180 §2  Reader Tests
;;;
;;; The examples below use the exact text from RFC 4180.
;;; -----------------------------------------------------------------------

(def-suite rfc-4180-reader
  :description "RFC 4180 §2 reader conformance"
  :in cl-csv.test)

(in-suite rfc-4180-reader)

;;; RFC 4180 §2 Rule 1:
;;; "Each record is located on a separate line, delimited by a line break
;;; (CRLF)."
;;;   field_name,field_name,field_name CRLF
;;;   aaa,bbb,ccc CRLF
;;;   zzz,yyy,xxx CRLF
(test rfc-4180/rule-1-crlf
  "Each record is on a separate line delimited by CRLF"
  (let ((input (crlf "aaa,bbb,ccc" "zzz,yyy,xxx")))
    (is (equal
         '(("aaa" "bbb" "ccc") ("zzz" "yyy" "xxx"))
         (cl-csv:read-csv input)))))

;;; RFC 4180 §2 Rule 2:
;;; "The last record in the file may or may not have an ending line break."
(test rfc-4180/rule-2-no-trailing-crlf
  "Last record may omit the trailing line break"
  (is (equal
       '(("aaa" "bbb" "ccc") ("zzz" "yyy" "xxx"))
       (cl-csv:read-csv (with-crlf "aaa,bbb,ccc" "zzz,yyy,xxx")))))

;;; RFC 4180 §2 Rule 3:
;;; "There may be an optional header record appearing as the first line of
;;; the file with the same format as normal record lines."
;;;   field_name,field_name,field_name CRLF
;;;   aaa,bbb,ccc CRLF
;;;   zzz,yyy,xxx CRLF
(test rfc-4180/rule-3-optional-header
  "Optional header record has the same format as data records"
  (let* ((input (crlf "field_name,field_name,field_name"
                      "aaa,bbb,ccc"
                      "zzz,yyy,xxx"))
         (rows (cl-csv:read-csv input)))
    (is (equal '("field_name" "field_name" "field_name") (first rows)))
    (is (equal '("aaa" "bbb" "ccc") (second rows)))
    (is (equal '("zzz" "yyy" "xxx") (third rows)))
    (is (= 3 (length rows)))))

;;; RFC 4180 §2 Rule 4:
;;; "Within the header and each record, there may be one or more fields,
;;; separated by commas."
;;;   aaa,bbb,ccc
(test rfc-4180/rule-4-comma-separator
  "Fields are separated by commas"
  (is (equal '(("aaa" "bbb" "ccc")) (cl-csv:read-csv "aaa,bbb,ccc"))))

;;; RFC 4180 §2 Rule 5:
;;; "Each field may or may not be enclosed in double quotes."
;;;   "aaa","bbb","ccc" CRLF
;;;   zzz,yyy,xxx
(test rfc-4180/rule-5-optional-quoting
  "Fields may optionally be enclosed in double quotes"
  (let ((input (with-crlf "\"aaa\",\"bbb\",\"ccc\"" "zzz,yyy,xxx")))
    (is (equal
         '(("aaa" "bbb" "ccc") ("zzz" "yyy" "xxx"))
         (cl-csv:read-csv input)))))

;;; RFC 4180 §2 Rule 6:
;;; "Fields containing line breaks (CRLF), double quotes, and commas
;;; should be enclosed in double-quotes."
;;;   "aaa","b CRLF
;;;   bb","ccc" CRLF
;;;   zzz,yyy,xxx
(test rfc-4180/rule-6-quoted-embedded-crlf
  "Fields containing CRLF must be enclosed in double-quotes"
  (let ((input (concatenate 'string
                             "\"aaa\",\"b" (string #\Return) (string #\Newline)
                             "bb\",\"ccc\"" (string #\Return) (string #\Newline)
                             "zzz,yyy,xxx")))
    (is (equal
         (list (list "aaa"
                     (concatenate 'string "b" (string #\Return) (string #\Newline) "bb")
                     "ccc")
               (list "zzz" "yyy" "xxx"))
         (cl-csv:read-csv input)))))

;;; RFC 4180 §2 Rule 7:
;;; "If double-quotes are used to enclose fields, then a double-quote
;;; appearing inside a field must be escaped by preceding it with another
;;; double quote."
;;;   "aaa","b""bb","ccc"
(test rfc-4180/rule-7-escaped-double-quote
  "Double-quote inside a quoted field is escaped by doubling"
  (is (equal
       '(("aaa" "b\"bb" "ccc"))
       (cl-csv:read-csv "\"aaa\",\"b\"\"bb\",\"ccc\""))))

;;; Additional reader edge cases derived from the RFC grammar

(test rfc-4180/empty-fields
  "Empty fields (leading, middle, trailing separator)"
  (is (equal '(("" "b" "")) (cl-csv:read-csv ",b,"))))

(test rfc-4180/single-field
  "Single field with no separators"
  (is (equal '(("hello")) (cl-csv:read-csv "hello"))))

(test rfc-4180/empty-quoted-field
  "An empty quoted field reads as empty string"
  (is (equal '(("" "b")) (cl-csv:read-csv "\"\",b"))))

(test rfc-4180/bare-lf-line-ending
  "Bare LF is accepted as a line ending (common Unix variant)"
  (is (equal
       '(("a" "b") ("c" "d"))
       (cl-csv:read-csv (format nil "a,b~%c,d")))))

(test rfc-4180/skip-empty-lines
  "skip-empty-lines option removes blank rows"
  (is (equal
       '(("a" "b") ("c" "d"))
       (cl-csv:read-csv (format nil "a,b~%~%c,d")
                        :skip-empty-lines t))))

(test rfc-4180/read-custom-separator
  "Custom separator is respected by the reader"
  (is (equal '(("a" "b" "c"))
             (cl-csv:read-csv (format nil "a~Cb~Cc" #\Tab #\Tab)
                              :separator #\Tab))))


;;; -----------------------------------------------------------------------
;;; RFC 4180 §2  Writer Tests
;;; -----------------------------------------------------------------------

(def-suite rfc-4180-writer
  :description "RFC 4180 §2 writer conformance"
  :in cl-csv.test)

(in-suite rfc-4180-writer)

;;; RFC 4180 §2 Rule 1: rows separated by CRLF
(test rfc-4180/write-crlf-terminator
  "Each row is terminated by CRLF"
  (let ((output (cl-csv:write-csv '(("aaa" "bbb") ("zzz" "yyy")) nil)))
    (is-true (search (coerce '(#\Return #\Newline) 'string) output))))

;;; RFC 4180 §2 Rule 7: comma in a field causes quoting
(test rfc-4180/write-quote-comma
  "A field containing a comma is enclosed in double quotes"
  (let ((output (cl-csv:write-csv '(("hello, world" "42")) nil)))
    (is-true (search "\"hello, world\"" output))))

;;; RFC 4180 §2 Rule 7: double-quote inside a field is escaped by doubling
(test rfc-4180/write-escape-quote
  "A double-quote inside a field is escaped by doubling"
  (let ((output (cl-csv:write-csv '(("say \"hi\"")) nil)))
    (is-true (search "\"say \"\"hi\"\"\"" output))))

;;; RFC 4180 §2 Rule 7: embedded newline causes quoting
(test rfc-4180/write-quote-newline
  "A field containing a newline is enclosed in double quotes"
  (let ((output (cl-csv:write-csv (list (list (format nil "line1~%line2"))) nil)))
    (is-true (char= #\" (char output 0)))))

;;; Round-trip: read(write(data)) = data
(test rfc-4180/round-trip
  "write-csv followed by read-csv is a round-trip identity"
  (let ((data '(("field_name" "field_name" "field_name")
                ("aaa" "bbb" "ccc")
                ("zzz" "yyy" "xxx"))))
    (is (equal data (cl-csv:read-csv (cl-csv:write-csv data nil))))))

;;; always-quote option
(test rfc-4180/write-always-quote
  "always-quote wraps every field regardless of content"
  (let ((output (cl-csv:write-csv '(("a" "b")) nil :always-quote t)))
    (is-true (search "\"a\"" output))
    (is-true (search "\"b\"" output))))

;;; Custom separator
(test rfc-4180/write-custom-separator
  "Custom separator is used for output"
  (let ((output (cl-csv:write-csv '(("a" "b" "c")) nil :separator #\Tab)))
    (is-true (find #\Tab output))
    (is-false (find #\, output))))

;;; write-csv returns string when output is nil
(test rfc-4180/write-to-string
  "write-csv with output=nil returns a string"
  (is (typep (cl-csv:write-csv '(("a" "b")) nil) 'string)))


;;; -----------------------------------------------------------------------
;;; RFC 7111 §3  Fragment Identifier Tests
;;;
;;; Fragment selector examples are from RFC 7111 §3 and its sub-sections.
;;; -----------------------------------------------------------------------

(def-suite rfc-7111-fragment
  :description "RFC 7111 §3 URI fragment identifier conformance"
  :in cl-csv.test)

(in-suite rfc-7111-fragment)

;;; RFC 7111 §3: "row=" selector
;;; "row=5" selects the 5th data row (1-based)
(test rfc-7111/row-single
  "row=N selects the Nth data row (RFC 7111 §3.1)"
  (let ((table '(("r1c1" "r1c2") ("r2c1" "r2c2") ("r3c1" "r3c2"))))
    (is (equal '(("r1c1" "r1c2")) (cl-csv:select-by-fragment table "row=1")))
    (is (equal '(("r2c1" "r2c2")) (cl-csv:select-by-fragment table "row=2")))))

;;; RFC 7111 §3.1: "row=5-7" selects rows 5 through 7 inclusive
(test rfc-7111/row-range
  "row=M-N selects rows M through N inclusive (RFC 7111 §3.1)"
  (let ((table '(("r1") ("r2") ("r3") ("r4") ("r5"))))
    (is (equal '(("r2") ("r3") ("r4")) (cl-csv:select-by-fragment table "row=2-4")))))

;;; RFC 7111 §3.1: open-ended range "row=3-"
(test rfc-7111/row-open-end-range
  "row=N- selects rows N through the last row (RFC 7111 §3.1)"
  (let ((table '(("r1") ("r2") ("r3") ("r4"))))
    (is (equal '(("r3") ("r4")) (cl-csv:select-by-fragment table "row=3-")))))

;;; RFC 7111 §3.1: "row=5,7" selects rows 5 and 7 (not 6)
(test rfc-7111/row-list
  "row=M,N selects rows M and N (RFC 7111 §3.1)"
  (let ((table '(("r1") ("r2") ("r3") ("r4") ("r5"))))
    (is (equal '(("r1") ("r3") ("r5"))
               (cl-csv:select-by-fragment table "row=1,3,5")))))

;;; RFC 7111 §3: "col=" selector
;;; "col=2" selects the 2nd column of every row
(test rfc-7111/col-single
  "col=N selects the Nth column of every row (RFC 7111 §3.2)"
  (let ((table '(("a" "b" "c") ("1" "2" "3"))))
    (is (equal '(("b") ("2")) (cl-csv:select-by-fragment table "col=2")))))

;;; RFC 7111 §3.2: "col=2-4" selects columns 2 through 4
(test rfc-7111/col-range
  "col=M-N selects columns M through N (RFC 7111 §3.2)"
  (let ((table '(("a" "b" "c" "d" "e") ("1" "2" "3" "4" "5"))))
    (is (equal '(("b" "c" "d") ("2" "3" "4"))
               (cl-csv:select-by-fragment table "col=2-4")))))

;;; RFC 7111 §3: "cell=" selector
;;; "cell=4-1" selects cell at row 4, column 1
(test rfc-7111/cell-single
  "cell=R-C selects cell at row R column C (RFC 7111 §3.3)"
  (let ((table '(("a" "b" "c")
                 ("d" "e" "f")
                 ("g" "h" "i"))))
    ;; cell=2-3 → row 2, col 3 → "f"; other cells masked with ""
    (is (equal '(("" "" "f"))
               (cl-csv:select-by-fragment table "cell=2-3")))))

;;; RFC 7111 §3.3: cell=*-2 selects all rows, column 2
(test rfc-7111/cell-wildcard-row
  "cell=*-C selects column C in all rows (RFC 7111 §3.3)"
  (let ((table '(("a" "b" "c") ("1" "2" "3") ("x" "y" "z"))))
    (is (equal '(("" "b" "") ("" "2" "") ("" "y" ""))
               (cl-csv:select-by-fragment table "cell=*-2")))))

;;; RFC 7111 §3.3: cell=R-* selects an entire row
(test rfc-7111/cell-wildcard-col
  "cell=R-* selects all columns of row R (RFC 7111 §3.3)"
  (let ((table '(("a" "b") ("c" "d") ("e" "f"))))
    (is (equal '(("c" "d"))
               (cl-csv:select-by-fragment table "cell=2-*")))))

;;; RFC 7111 §3: multiple cell pairs
;;; "cell=3-2,5-4" selects two specific cells
(test rfc-7111/cell-multiple-pairs
  "cell=R1-C1,R2-C2 selects two cells (RFC 7111 §3.3)"
  (let ((table '(("a" "b" "c" "d")
                 ("e" "f" "g" "h")
                 ("i" "j" "k" "l")
                 ("m" "n" "o" "p")
                 ("q" "r" "s" "t"))))
    ;; cell=1-2,3-4 → (row1,col2)="b" and (row3,col4)="l"
    (is (equal '(("" "b" "" "")
                 ("" "" "" "l"))
               (cl-csv:select-by-fragment table "cell=1-2,3-4")))))

;;; RFC 7111 §2.1: include-header option
;;; Header row is not counted in the 1-based row numbering.
(test rfc-7111/include-header
  "include-header: header row is exempt from row numbering"
  (let ((table '(("name" "age" "city")
                 ("Alice" "30" "NY")
                 ("Bob"   "25" "LA")
                 ("Carol" "35" "SF"))))
    (let ((result (cl-csv:select-by-fragment table "row=1,3" :include-header t)))
      (is (equal '("name" "age" "city") (first result)))
      (is (equal '("Alice" "30" "NY")   (second result)))
      (is (equal '("Carol" "35" "SF")   (third result)))
      (is (= 3 (length result))))))

;;; RFC 7111 §2: multiple selectors separated by ";"
(test rfc-7111/multiple-selectors
  "Semicolon separates multiple selectors (RFC 7111 §2)"
  (let ((r (cl-csv:parse-fragment "row=1;col=2")))
    (is (= 2 (length r)))
    (is (eq :row (getf (first r) :type)))
    (is (eq :col (getf (second r) :type)))))

;;; RFC 7111 §2: wildcard * in row/col position
(test rfc-7111/wildcard-star
  "\"*\" in a row selector matches all rows (RFC 7111 §2)"
  (let ((r (cl-csv:parse-fragment "row=*")))
    (is (equal (cons 1 nil) (first (getf (first r) :positions))))))

;;; RFC 7111 §2: open-ended range "5-" means row 5 to the end
(test rfc-7111/open-ended-range
  "N- is an open-ended range (RFC 7111 §2)"
  (let ((r (cl-csv:parse-fragment "row=3-")))
    (is (equal (cons 3 nil) (first (getf (first r) :positions))))))

;;; RFC 7111 §2: leading-dash range "-7" means 1 to 7
(test rfc-7111/leading-dash-range
  "\"-N\" range means rows 1 through N (RFC 7111 §2)"
  (let ((r (cl-csv:parse-fragment "row=-3")))
    (is (equal (cons 1 3) (first (getf (first r) :positions))))))


;;; Default: has-header t — second return value is the first row (header).
(test has-header/default-returns-header-as-second-value
  "read-csv with default has-header returns the header row as second value"
  (multiple-value-bind (rows header)
      (cl-csv:read-csv (with-crlf "name,age" "Alice,30" "Bob,25"))
    (is (= 3 (length rows)))
    (is (equal '("name" "age") header))))

;;; Default: has-header t — primary return value is unchanged (all rows).
(test has-header/default-primary-value-unchanged
  "read-csv with default has-header still returns all rows as primary value"
  (let ((rows (cl-csv:read-csv (with-crlf "name,age" "Alice,30"))))
    (is (= 2 (length rows)))
    (is (equal '("name" "age") (first rows)))))

;;; Explicit has-header t — same as default.
(test has-header/explicit-t
  "read-csv with explicit has-header t returns header as second value"
  (multiple-value-bind (rows header)
      (cl-csv:read-csv (with-crlf "id,val" "1,a") :has-header t)
    (is (= 2 (length rows)))
    (is (equal '("id" "val") header))))

;;; has-header nil — second return value is nil (no header).
(test has-header/nil-returns-nil-header
  "read-csv with has-header nil returns nil as second value"
  (multiple-value-bind (rows header)
      (cl-csv:read-csv (with-crlf "Alice,30" "Bob,25") :has-header nil)
    (is (= 2 (length rows)))
    (is (null header))))

;;; has-header nil — primary return value is unchanged (all rows are data).
(test has-header/nil-primary-value-contains-all-rows
  "read-csv with has-header nil returns all rows as primary value"
  (multiple-value-bind (rows header)
      (cl-csv:read-csv (with-crlf "Alice,30" "Bob,25") :has-header nil)
    (declare (ignore header))
    (is (equal '(("Alice" "30") ("Bob" "25")) rows))))

;;; Empty input — has-header t, no rows → second value is nil.
(test has-header/empty-input
  "read-csv on empty input with has-header t returns nil for both values"
  (multiple-value-bind (rows header)
      (cl-csv:read-csv "" :has-header t)
    (is (null rows))
    (is (null header))))

;;; Single row (header only) — has-header t.
(test has-header/single-row-is-header
  "read-csv on a single-row CSV returns that row as both the rows list and the header"
  (multiple-value-bind (rows header)
      (cl-csv:read-csv "col1,col2,col3" :has-header t)
    (is (= 1 (length rows)))
    (is (equal '("col1" "col2" "col3") header))))

;;; write-csv without headers writes all rows as data (no header line).
(test has-header/write-csv-no-header
  "write-csv without :headers writes data rows only"
  (is (string= (cl-csv:write-csv '(("Alice" "30") ("Bob" "25")) nil)
               (crlf "Alice,30" "Bob,25"))))

;;; write-csv with headers list prepends the header row.
(test has-header/write-csv-prepends-header
  "write-csv with :headers list prepends it as the first row"
  (is (string= (cl-csv:write-csv '(("Alice" "30") ("Bob" "25")) nil
                                 :headers '("name" "age"))
               (crlf "name,age" "Alice,30" "Bob,25"))))

;;; write-csv with headers nil produces no header row.
(test has-header/write-csv-nil-no-header-line
  "write-csv with :headers nil produces no header row"
  (is (string= (cl-csv:write-csv '(("a" "b")) nil :headers nil)
               (crlf "a,b"))))

;;; write-csv with headers honours quoting options.
(test has-header/write-csv-header-quoting
  "write-csv quotes header fields that contain special characters"
  (let ((output (cl-csv:write-csv '(("1" "2")) nil
                                  :headers '("col,a" "col b"))))
    (is-true (search "\"col,a\"" output))))


;;; -----------------------------------------------------------------------
;;; Error / condition tests
;;; -----------------------------------------------------------------------

(def-suite csv-conditions
  :description "csv-error and csv-parse-error conditions"
  :in cl-csv.test)

(in-suite csv-conditions)

(test csv-conditions/parse-error-on-bad-fragment
  "An unknown selector keyword signals csv-parse-error"
  (signals cl-csv:csv-parse-error (cl-csv:parse-fragment "unknown=1")))

(test csv-conditions/parse-error-message
  "csv-parse-error carries a human-readable message"
  (handler-case (cl-csv:parse-fragment "bad=selector")
    (cl-csv:csv-parse-error (c)
      (is (typep (cl-csv:csv-parse-error-message c) 'string)))))

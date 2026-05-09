(in-package :io.github.cl-sdk.ini)

(defun %field-needs-quoting-p (str separator quote)
  "Return T if STR must be quoted according to RFC 4180 §2."
  (loop for ch across str
	thereis (or (char= ch separator)
		   (char= ch quote)
		   (char= ch #\Return)
		   (char= ch #\Newline))))

(defun write-csv-field (field stream &key
				       (separator    *separator*)
				       (quote        *quote*)
				       (always-quote *always-quote*))
  "Write one CSV field value to STREAM, quoting when necessary.

FIELD is coerced to a string via PRINC-TO-STRING if it is not already
one.  Quoting follows RFC 4180 §2 rules 5-7: the field is wrapped in
QUOTE characters and any occurrence of QUOTE inside the field is escaped
by doubling it."
  (let ((str (if (stringp field) field (princ-to-string field))))
    (if (or always-quote (%field-needs-quoting-p str separator quote))
	(progn
	  (write-char quote stream)
	  (loop for ch across str
		do (when (char= ch quote)
		     (write-char quote stream))  ; escape by doubling
		   (write-char ch stream))
	  (write-char quote stream))
	(write-string str stream))))

(defun write-csv-row (row stream &key
				   (separator    *separator*)
				   (quote        *quote*)
				   (newline      *newline*)
				   (always-quote *always-quote*))
  "Write one CSV row (a list of field values) to STREAM.

A NEWLINE string is appended after the last field.  Per RFC 4180 §2
rule 2, the final record in a file MAY omit the trailing line break;
callers that want that behaviour should write all but the last row with
this function and handle the last row manually."
  (loop for (field . rest) on row
	do (write-csv-field field stream
			    :separator    separator
			    :quote        quote
			    :always-quote always-quote)
	   (when rest
	     (write-char separator stream)))
  (write-string newline stream))

(defun write-csv (rows output &key
				(separator    *separator*)
				(quote        *quote*)
				(newline      *newline*)
				(always-quote *always-quote*)
				(headers      nil))
  "Write CSV rows to OUTPUT.

ROWS is a sequence of data rows; each row is a list of field values.
Field values are coerced to strings via PRINC-TO-STRING.

OUTPUT may be:
  * NIL       — result is returned as a fresh string
  * T         — written to *STANDARD-OUTPUT*
  * a STREAM  — written to that stream
  * a PATHNAME — file created (or overwritten) with UTF-8 encoding

Options:
  :SEPARATOR    — field-separator character (default *SEPARATOR*)
  :QUOTE        — quoting character (default *QUOTE*)
  :NEWLINE      — row-terminator string (default *NEWLINE*, i.e. CRLF)
  :ALWAYS-QUOTE — when non-NIL every field is quoted
  :HEADERS      — a list of field names to write as the header row before
the data rows, or NIL (the default) for no header.
		  When provided, the header is written first and ROWS
		  contains only data rows.

Conforms to RFC 4180 §2 (header support per RFC 4180 §3 MIME parameter)."
  (flet ((do-write (stream)
	   (when headers
	     (write-csv-row headers stream
			    :separator    separator
			    :quote        quote
			    :newline      newline
			    :always-quote always-quote))
	   (dolist (row rows)
	     (write-csv-row row stream
			    :separator    separator
			    :quote        quote
			    :newline      newline
			    :always-quote always-quote))))
    (etypecase output
      (null
       (with-output-to-string (s)
	 (do-write s)))
      ((eql t)
       (do-write *standard-output*))
      (stream
       (do-write output))
      (pathname
       (with-open-file (s output
			  :direction         :output
			  :if-exists         :supersede
			  :external-format   :utf-8)
	 (do-write s))))))


;;; -----------------------------------------------------------------------
;;; RFC 7111 — URI Fragment Identifiers for text/csv
;;;
;;; Grammar (RFC 7111 §2):
;;;
;;;   csv-fragment = csv-selector *(";" csv-selector)
;;;   csv-selector = rowsel / colsel / cellsel
;;;   rowsel       = "row=" rowspec
;;;   colsel       = "col=" colspec
;;;   cellsel      = "cell=" cellspec
;;;   rowspec      = position *("," position)
;;;   colspec      = position *("," position)
;;;   cellspec     = cellrow "-" cellcol *("," cellrow "-" cellcol)
;;;   position     = number / range
;;;   range        = number "-" / number "-" number / "-" number
;;;   cellrow      = number / "*"
;;;   cellcol      = number / "*"
;;;   number       = 1*DIGIT   (1-based)
;;; -----------------------------------------------------------------------

(defun %parse-position (token)
  "Parse a single position TOKEN into a cons (START . END).

  \"5\"    → (5 . 5)
  \"3-7\"  → (3 . 7)
  \"3-\"   → (3 . nil)     nil means 'to the end'
  \"-7\"   → (1 . 7)
  \"*\"    → (1 . nil)     the whole dimension"
  (cond
    ((string= token "*")
     (cons 1 nil))
    ((find #\- token)
     (let* ((dash  (position #\- token))
	    (left  (subseq token 0 dash))
	    (right (subseq token (1+ dash))))
       (cons (if (string= left  "") 1   (parse-integer left))
	     (if (string= right "") nil (parse-integer right)))))
    (t
     (let ((n (parse-integer token :junk-allowed t)))
       (unless n
	 (error 'csv-parse-error
		:message (format nil "Invalid position token ~S: \
expected a 1-based number (e.g. \"5\"), a range (e.g. \"3-7\", \"3-\", \"-7\"), or \"*\""
				 token)))
       (cons n n)))))

;;; Internal helper: split STRING on every occurrence of DELIMITER char.
;;; Named with % prefix and a distinct name to avoid conflict with the
;;; popular cl-split-sequence / split-sequence ASDF library.
(defun %split-on (delimiter string)
  (loop with start = 0
	for i from 0 to (length string)
	when (or (= i (length string))
		(char= (char string i) delimiter))
	  collect (subseq string start i)
	  and do (setf start (1+ i))))

(defun %parse-positions (spec)
  "Parse a comma-separated list of positions/ranges into a list of conses."
  (mapcar #'%parse-position (%split-on #\, spec)))

(defun %parse-cellspec (spec)
  "Parse a cell specification into a list of ((row-start . row-end) . (col-start . col-end))."
  (mapcar (lambda (pair-str)
	    (let ((dash (position #\- pair-str)))
	      (unless dash
		(error 'csv-parse-error
		       :message (format nil "Invalid cell pair ~S: expected format row-col \
(e.g. \"1-2\" or \"*-3\")"
					pair-str)))
	      (cons (%parse-position (subseq pair-str 0 dash))
		    (%parse-position (subseq pair-str (1+ dash))))))
	  (%split-on #\, spec)))

(defun parse-fragment (fragment)
  "Parse an RFC 7111 URI fragment identifier string into a list of selector plists.

Each plist has the form:
  (:type :row  :positions <list-of-(start . end)>)
  (:type :col  :positions <list-of-(start . end)>)
  (:type :cell :pairs     <list-of-((row-start . row-end) . (col-start . col-end))>)

Multiple selectors separated by \";\" are all returned.

Example:
  (parse-fragment \"row=1,3-5\")
  → ((:type :row :positions ((1 . 1) (3 . 5))))

  (parse-fragment \"col=2-4;row=1\")
  → ((:type :col :positions ((2 . 4)))
     (:type :row :positions ((1 . 1))))

  (parse-fragment \"cell=1-2,3-4\")
  → ((:type :cell :pairs (((1 . 1) . (2 . 2)) ((3 . 3) . (4 . 4)))))"
  (loop for selector-str in (%split-on #\; fragment)
	when (> (length selector-str) 0)
	  collect
	  (cond
	    ((and (>= (length selector-str) 4)
		(string= "row=" (subseq selector-str 0 4)))
	     (list :type :row
		   :positions (%parse-positions (subseq selector-str 4))))
	    ((and (>= (length selector-str) 4)
		(string= "col=" (subseq selector-str 0 4)))
	     (list :type :col
		   :positions (%parse-positions (subseq selector-str 4))))
	    ((and (>= (length selector-str) 5)
		(string= "cell=" (subseq selector-str 0 5)))
	     (list :type :cell
		   :pairs (%parse-cellspec (subseq selector-str 5))))
	    (t
	     (error 'csv-parse-error
		    :message (format nil "Unknown selector: ~S" selector-str))))))

(defun %range-includes-p (range n)
  "Return T if 1-based index N falls within RANGE (a (start . end) cons).
END = NIL means 'unbounded'."
  (and (>= n (car range))
     (or (null (cdr range))
	(<= n (cdr range)))))

(defun %row-selected-p (selectors row-index)
  "Return T if ROW-INDEX (1-based) is selected by the :row selectors."
  (some (lambda (sel)
	  (and (eq :row (getf sel :type))
	     (some (lambda (pos) (%range-includes-p pos row-index))
		   (getf sel :positions))))
	selectors))

(defun %col-selected-p (selectors col-index)
  "Return T if COL-INDEX (1-based) is selected by the :col selectors."
  (some (lambda (sel)
	  (and (eq :col (getf sel :type))
	     (some (lambda (pos) (%range-includes-p pos col-index))
		   (getf sel :positions))))
	selectors))

(defun %cell-selected-p (selectors row-index col-index)
  "Return T if the cell at (ROW-INDEX, COL-INDEX) (both 1-based) is
selected by the :cell selectors."
  (some (lambda (sel)
	  (and (eq :cell (getf sel :type))
	     (some (lambda (pair)
		     (and (%range-includes-p (car pair) row-index)
			(%range-includes-p (cdr pair) col-index)))
		   (getf sel :pairs))))
	selectors))

(defun select-by-fragment (rows fragment &key include-header)
  "Apply an RFC 7111 fragment identifier string to a list of CSV ROWS.

Returns a sub-table as a list of string lists.  Row and column numbers
are 1-based per RFC 7111.

If INCLUDE-HEADER is non-NIL, the first row of ROWS is treated as a
header and is always included in the result when any row selector is
active; it does not count toward the 1-based row numbering used in the
fragment.

Selector semantics (RFC 7111 §3):
  row=  — selects entire rows; only the selected rows are returned.
  col=  — selects entire columns; each row is filtered to those columns.
  cell= — selects individual cells; fields outside the selection are
replaced with empty strings, and rows with no selected cells
	  are omitted.

Multiple selectors of the same type within one FRAGMENT string are
combined with logical OR.  Multiple selectors of different types are
applied independently; the result is the union of the individual
results (RFC 7111 §3.1 note)."
  (let* ((selectors    (parse-fragment fragment))
	 (has-row      (some (lambda (s) (eq :row  (getf s :type))) selectors))
	 (has-col      (some (lambda (s) (eq :col  (getf s :type))) selectors))
	 (has-cell     (some (lambda (s) (eq :cell (getf s :type))) selectors))
	 (data-rows    (if include-header (rest rows) rows))
	 (header       (when include-header (first rows)))
	 (result       '()))

    (loop for row in data-rows
	  for row-idx from 1
	  do (let ((row-ok   (or (not has-row)
				(%row-selected-p selectors row-idx)))
		   (filtered-row
		     (if has-col
			 (loop for field in row
			       for col-idx from 1
			       when (%col-selected-p selectors col-idx)
				 collect field)
			 row)))

	       (cond
		 ;; Cell selection: replace non-selected cells with ""
		 (has-cell
		  (let ((masked
			  (loop for field in row
				for col-idx from 1
				collect (if (%cell-selected-p selectors row-idx col-idx)
					    field
					    ""))))
		    (when (some (lambda (f) (not (string= f ""))) masked)
		      (push masked result))))

		 ;; Row and/or col selection
		 (row-ok
		  (push filtered-row result)))))

    ;; Prepend header if requested and there were any row/col selectors
    (let ((final (nreverse result)))
      (if (and include-header header (or has-row has-col))
	  (cons (if has-col
		    (loop for field in header
			  for col-idx from 1
			  when (%col-selected-p selectors col-idx)
			    collect field)
		    header)
		final)
	  final))))

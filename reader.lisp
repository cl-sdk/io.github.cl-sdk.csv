(in-package :io.github.cl-sdk.csv)

(defun read-csv-row (stream &key (separator *separator*) (quote *quote*))
  "Read one CSV row from STREAM and return it as a list of strings.

Returns NIL at end-of-file with no pending data.  Partial rows at EOF
(i.e. the file does not end with a newline) are returned normally.

Parsing rules follow RFC 4180 §2:
  * Fields may be enclosed in QUOTE characters.
  * A QUOTE inside a quoted field is escaped by doubling it.
  * Rows are terminated by CRLF or bare LF (bare CR is treated as data).
  * An unquoted row that consists of a single empty string represents an
    empty line; callers that wish to skip such lines may test for it."
  (let ((fields       '())
	(field        (make-string-output-stream))
	(in-quotes    nil)
	(field-active nil)) ; at least one character written to this field?
    (loop
      (let ((ch (read-char stream nil nil)))
	(cond
	  ;; ── End of file ────────────────────────────────────────────────
	  ((null ch)
	   ;; We have a pending row if: we already collected at least one
	   ;; field (a separator was seen), the current field buffer has
	   ;; content, or we are inside a quoted field.
	   ;; A truly empty stream (no characters at all) returns NIL.
	   (cond
	     ((or fields field-active in-quotes)
	      (push (get-output-stream-string field) fields)
	      (return (nreverse fields)))
	     (t
	      (return nil))))

	  ;; ── Inside a quoted field: possible end-quote or escaped quote ─
	  ((and in-quotes (char= ch quote))
	   (let ((next (peek-char nil stream nil nil)))
	     (cond
	       ;; Doubled quote → literal quote character (RFC 4180 §2 rule 7)
	       ((and next (char= next quote))
		(read-char stream)
		(write-char ch field))
	       ;; Single quote → end of quoted section
	       (t
		(setf in-quotes nil)))))

	  ;; ── Start of quoted field ──────────────────────────────────────
	  ((and (not in-quotes) (char= ch quote))
	   (setf in-quotes    t
		 field-active t))

	  ;; ── Field separator (only outside quotes) ─────────────────────
	  ((and (not in-quotes) (char= ch separator))
	   (push (get-output-stream-string field) fields)
	   (setf field        (make-string-output-stream)
		 field-active nil))

	  ;; ── CRLF line ending (RFC 4180 §2 rule 1) ─────────────────────
	  ((and (not in-quotes) (char= ch #\Return))
	   (let ((next (peek-char nil stream nil nil)))
	     (when (and next (char= next #\Newline))
	       (read-char stream)))	; consume the LF
	   (push (get-output-stream-string field) fields)
	   (return (nreverse fields)))

	  ;; ── Bare LF line ending ────────────────────────────────────────
	  ((and (not in-quotes) (char= ch #\Newline))
	   (push (get-output-stream-string field) fields)
	   (return (nreverse fields)))

	  ;; ── Ordinary character ─────────────────────────────────────────
	  (t
	   (write-char ch field)
	   (setf field-active t)))))))

(defun %skip-csv-row-p (row skip-empty-lines)
  (and skip-empty-lines
     (= 1 (length row))
     (string= "" (first row))))

(defclass default-csv-parser (csv-parser)
  ((header :initform nil  :accessor default-csv-parser-header)
   (rows   :initform '()  :accessor default-csv-parser-rows))
  (:documentation "Default parser implementation used by PARSE-CSV and READ-CSV."))

(defmethod csv-parser-begin-document ((parser default-csv-parser))
  (setf (default-csv-parser-rows parser) '()
	(default-csv-parser-header parser) nil))

(defmethod csv-parser-header ((parser default-csv-parser) row)
  (setf (default-csv-parser-header parser) row))

(defmethod csv-parser-line ((parser default-csv-parser) row)
  (push row (default-csv-parser-rows parser)))

(defmethod csv-parser-result ((parser default-csv-parser))
  (cons (default-csv-parser-header parser)
	(nreverse (default-csv-parser-rows parser))))

(defmethod csv-parser-end-document ((parser default-csv-parser))
  nil)

(defun parse-csv (input
		  &key
		    (parser (make-instance 'default-csv-parser))
		    (separator       *separator*)
		    (quote           *quote*)
		    skip-empty-lines
		    (has-header      t))
  "Read INPUT, emit SAX-like events, and return PARSER's result.

PARSER may be NIL, a function, or an instance of CSV-PARSER.
When PARSER is NIL, a default collecting parser is used and the return
values match READ-CSV: (data-rows header-or-nil).

Function parsers are called with two arguments: an event keyword and its
payload.  CSV-PARSER instances receive the corresponding generic-function
callbacks.

The supported events are:
  :BEGIN-DOCUMENT  — payload is NIL
  :HEADER          — payload is the header row
  :LINE            — payload is a data row
  :END-DOCUMENT    — payload is NIL

INPUT and keyword arguments match READ-CSV.  When HAS-HEADER is non-NIL,
the first non-skipped row is emitted as :HEADER; otherwise every row is
emitted as :LINE."
  (flet ((do-parse (stream)
	   (csv-parser-begin-document parser)
	   (loop with header-emitted-p = nil
		 for row = (read-csv-row stream
					 :separator separator
					 :quote     quote)
		 while row
		 unless (%skip-csv-row-p row skip-empty-lines)
		   do (if (and has-header (not header-emitted-p))
			  (progn
			    (csv-parser-header parser row)
			    (setf header-emitted-p t))
			  (csv-parser-line parser row)))
	   (csv-parser-end-document parser)
	   parser))
    (let ((stream (etypecase input
		    (stream input)
		    (string (make-string-input-stream input)))))
      (csv-parser-result (do-parse stream)))))

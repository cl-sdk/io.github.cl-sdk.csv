# cl-csv

A CSV reader and writer for Common Lisp, conforming to
[RFC 4180](https://www.rfc-editor.org/rfc/rfc4180) and with support for
[RFC 7111](https://www.rfc-editor.org/rfc/rfc7111) URI fragment identifiers.

## Loading

```lisp
(ql:quickload :io.github.cl-sdk.csv)
```

## Running Tests

The test suite uses the
[FiveAM](https://common-lisp-libraries.readthedocs.io/fiveam/) framework.

```lisp
;; From the REPL, with the project root in ASDF's search path:
(ql:quickload :io.github.cl-sdk.csv.test)
(fiveam:run-all-tests)
```

Or from a shell:

```sh
sbcl --noinform \
     --eval '(require :asdf)' \
     --eval '(push #P"/path/to/cl-csv/" asdf:*central-registry*)' \
     --eval '(asdf:load-system :io.github.cl-sdk.csv.test)' \
     --eval '(unless (fiveam:run-all-tests) (uiop:quit -1))' \
     --eval '(uiop:quit)'
```

## CLI: CSV to s-expressions

Build a standalone executable:

```sh
make cli
```

This produces `csv-to-list` in the current directory.

Usage:

```sh
./cl-csv-dump data.csv
cat data.csv | ./cl-csv-dump
./cl-csv-dump -
./cl-csv-dump --no-header data.csv   # treat file as having no header
```

---

## Dynamic variables

| Variable | Default | Description |
|---|---|---|
| `*separator*` | `#\,` | Field-separator character |
| `*quote*` | `#\"` | Quoting character |
| `*newline*` | `"\r\n"` | Row terminator written on output (RFC 4180 mandates CRLF) |
| `*always-quote*` | `nil` | When non-`nil`, every output field is quoted |

---

## Reader

Read one row from a stream:

```lisp
(with-input-from-string (s "a,b,c")
  (io.github.cl-sdk.csv:read-csv-row s))
; => ("a" "b" "c")
```

```lisp
;; Default: file has a header — header returned as second value, excluded from rows
(io.github.cl-sdk.csv:read-csv "name,age
Alice,30
Bob,25")
; primary  => (("Alice" "30") ("Bob" "25"))
; secondary => ("name" "age")

;; Convenient destructuring with multiple-value-bind
(multiple-value-bind (rows header)
    (io.github.cl-sdk.csv:read-csv "name,age
Alice,30
Bob,25")
  (format t "Header: ~a~%" header)
  (format t "Data:   ~a~%" rows))
; Header: (name age)
; Data:   ((Alice 30) (Bob 25))

;; File has no header — second value is nil, all rows are data
(multiple-value-bind (rows header)
    (io.github.cl-sdk.csv:read-csv "Alice,30
Bob,25" :has-header nil)
  (format t "Header: ~a~%" header)
  (format t "Data:   ~a~%" rows))
; Header: nil
; Data:   ((Alice 30) (Bob 25))
```

Stream rows as events instead of materializing the full table:

```lisp
(io.github.cl-sdk.csv:parse-csv "name,age
Alice,30
Bob,25"
  (lambda (event payload)
    (format t "~a => ~s~%" event payload)))
;; :BEGIN-DOCUMENT => NIL
;; :HEADER => ("name" "age")
;; :LINE => ("Alice" "30")
;; :LINE => ("Bob" "25")
;; :END-DOCUMENT => NIL
```

Omit the parser argument to use the default collecting parser:

```lisp
(multiple-value-bind (rows header)
    (io.github.cl-sdk.csv:parse-csv "name,age
Alice,30
Bob,25")
  (list rows header))
; => ((("Alice" "30") ("Bob" "25")) ("name" "age"))
```

Custom parser implementations can subclass `io.github.cl-sdk.csv:csv-parser` and define the
event callbacks they care about:

```lisp
(defclass counting-parser (io.github.cl-sdk.csv:csv-parser)
  ((lines :initform 0 :accessor lines)))

(defmethod io.github.cl-sdk.csv:csv-parser-line ((parser counting-parser) row)
  (declare (ignore row))
  (incf (lines parser)))

(defmethod io.github.cl-sdk.csv:csv-parser-result ((parser counting-parser))
  (lines parser))

(io.github.cl-sdk.csv:parse-csv "name,age
Alice,30
Bob,25"
                  (make-instance 'counting-parser))
; => 2
```

---

## Writer

Write a single row:

```lisp
(io.github.cl-sdk.csv:write-csv-row '("Alice" "30") *standard-output*)
; prints: Alice,30\r\n
```

Write all rows to output:

* `nil`      → returns the CSV as a fresh string
* `t`        → writes to `*standard-output*`
* stream     → writes to that stream
* pathname   → writes to file (UTF-8, overwrites if exists)

```lisp
;; No header (default) — rows are plain data
(io.github.cl-sdk.csv:write-csv '(("Alice" "30") ("Bob" "25")) nil)
; => "Alice,30\r\nBob,25\r\n"

;; With a header passed explicitly
(io.github.cl-sdk.csv:write-csv '(("Alice" "30") ("Bob" "25")) nil
                  :headers '("name" "age"))
; => "name,age\r\nAlice,30\r\nBob,25\r\n"
```

Force quoting:

```lisp
(io.github.cl-sdk.csv:write-csv '(("a" "b")) nil :always-quote t)
; => "\"a\",\"b\"\r\n"
```

Use tab as separator (TSV):

```lisp
(io.github.cl-sdk.csv:write-csv '(("a" "b")) nil :separator #\Tab)
; => "a\tb\r\n"
```

---

## RFC 7111 fragment identifiers

RFC 7111 defines URI fragment identifiers for selecting subsets of a
`text/csv` resource:

```
http://example.com/data.csv#row=1,3-5
http://example.com/data.csv#col=2-4
http://example.com/data.csv#cell=1-2,3-4
```

Parse RFC 7111 fragment strings:

```lisp
(io.github.cl-sdk.csv:parse-fragment "row=1,3-5")
; => ((:TYPE :ROW :POSITIONS ((1 . 1) (3 . 5))))

(io.github.cl-sdk.csv:parse-fragment "col=2-4;row=1")
; => ((:TYPE :COL :POSITIONS ((2 . 4)))
;     (:TYPE :ROW :POSITIONS ((1 . 1))))
```

Apply fragment identifiers to parsed CSV tables (row and column numbers are 1-based):

```lisp
(defvar *table*
  '(("name" "age" "city")
    ("Alice" "30" "NY")
    ("Bob"   "25" "LA")
    ("Carol" "35" "SF")))

;; Select rows 1 and 3
(io.github.cl-sdk.csv:select-by-fragment *table* "row=1,3")
; => (("Alice" "30" "NY") ("Carol" "35" "SF"))

;; Select column 1 (name) for all rows, keeping the header
(io.github.cl-sdk.csv:select-by-fragment *table* "col=1" :include-header t)
; => (("name") ("Alice") ("Bob") ("Carol"))

;; Select a specific cell range
(io.github.cl-sdk.csv:select-by-fragment *table* "cell=1-1,2-2")
; => (("Alice" "" "") ("" "25" ""))
```

---

## MIME type

The registered MIME type for CSV is **`text/csv`** (RFC 4180 §3).
Relevant parameters:

| Parameter | Description |
|---|---|
| `charset` | Character encoding; defaults to `US-ASCII` per RFC 2046 §4.1.2 |
| `header` | `present` if the first record is a header row, `absent` otherwise |

Example `Content-Type` header:

```
Content-Type: text/csv; charset=UTF-8; header=present
```

---

## License

See [LICENSE](LICENSE).

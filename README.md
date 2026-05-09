# cl-csv

A CSV reader and writer for Common Lisp, conforming to
[RFC 4180](https://www.rfc-editor.org/rfc/rfc4180) and with support for
[RFC 7111](https://www.rfc-editor.org/rfc/rfc7111) URI fragment identifiers.

## Loading

```lisp
(ql:quickload :cl-csv)
```

## Running Tests

The test suite uses the [Parachute](https://shinmera.github.io/parachute/)
framework.  Parachute and its dependencies are vendored under `vendor/`
so no additional downloads are needed.

```lisp
;; From the REPL, with the project root in ASDF's search path:
(asdf:test-system :cl-csv)
```

Or from a shell:

```sh
sbcl --noinform \
     --eval '(require :asdf)' \
     --eval '(push #P"/path/to/cl-csv/" asdf:*central-registry*)' \
     --eval '(asdf:test-system :cl-csv)' \
     --eval '(exit)'
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

### `read-csv-row stream &key separator quote` → `list | nil`

Read one row from `stream`.  Returns a list of strings, or `nil` at
end-of-file.

```lisp
(with-input-from-string (s "a,b,c")
  (cl-csv:read-csv-row s))
; => ("a" "b" "c")
```

### `read-csv input &key separator quote skip-empty-lines has-header` → `rows, header`

Read all rows from `input` (stream, string, or pathname).  Returns two
values: the primary value is always the complete list of rows (as with
previous versions), and the secondary value is the header row or `nil`.

| Keyword | Default | Description |
|---|---|---|
| `:has-header` | `t` | When non-`nil`, the file is assumed to have a header record as its first row; the second return value is that row.  When `nil`, no header is expected and the second value is `nil`. |

```lisp
;; Default: file has a header — header returned as second value
(cl-csv:read-csv "name,age
Alice,30
Bob,25")
; primary  => (("name" "age") ("Alice" "30") ("Bob" "25"))
; secondary => ("name" "age")

;; Convenient destructuring with multiple-value-bind
(multiple-value-bind (rows header)
    (cl-csv:read-csv "name,age
Alice,30
Bob,25")
  (format t "Header: ~a~%" header)
  (format t "Data:   ~a~%" (rest rows)))
; Header: (name age)
; Data:   ((Alice 30) (Bob 25))

;; File has no header — second value is nil, all rows are data
(multiple-value-bind (rows header)
    (cl-csv:read-csv "Alice,30
Bob,25" :has-header nil)
  (format t "Header: ~a~%" header)
  (format t "Data:   ~a~%" rows))
; Header: nil
; Data:   ((Alice 30) (Bob 25))
```

---

## Writer

### `write-csv-field field stream &key separator quote always-quote`

Write a single field value to `stream`, quoting if necessary.

### `write-csv-row row stream &key separator quote newline always-quote`

Write a list of field values as one CSV row (appends `newline`).

```lisp
(cl-csv:write-csv-row '("Alice" "30") *standard-output*)
; prints: Alice,30\r\n
```

### `write-csv rows output &key separator quote newline always-quote has-header` → `string | nil`

Write all rows to `output`.

* `nil`      → returns the CSV as a fresh string
* `t`        → writes to `*standard-output*`
* stream     → writes to that stream
* pathname   → writes to file (UTF-8, overwrites if exists)

| Keyword | Default | Description |
|---|---|---|
| `:has-header` | `nil` | A list of field names to write as the header row before the data rows, or `nil` (the default) for no header.  When provided, the header is written first and `rows` contains only data rows. |

```lisp
;; No header (default) — rows are plain data
(cl-csv:write-csv '(("Alice" "30") ("Bob" "25")) nil)
; => "Alice,30\r\nBob,25\r\n"

;; With a header passed explicitly
(cl-csv:write-csv '(("Alice" "30") ("Bob" "25")) nil
                  :has-header '("name" "age"))
; => "name,age\r\nAlice,30\r\nBob,25\r\n"
```

Force quoting:

```lisp
(cl-csv:write-csv '(("a" "b")) nil :always-quote t)
; => "\"a\",\"b\"\r\n"
```

Use tab as separator (TSV):

```lisp
(cl-csv:write-csv '(("a" "b")) nil :separator #\Tab)
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

### `parse-fragment fragment` → `list`

Parse an RFC 7111 fragment string into a list of selector plists.

```lisp
(cl-csv:parse-fragment "row=1,3-5")
; => ((:TYPE :ROW :POSITIONS ((1 . 1) (3 . 5))))

(cl-csv:parse-fragment "col=2-4;row=1")
; => ((:TYPE :COL :POSITIONS ((2 . 4)))
;     (:TYPE :ROW :POSITIONS ((1 . 1))))
```

### `select-by-fragment rows fragment &key include-header` → `list`

Apply a fragment identifier to a parsed CSV table (list of string lists).
Row and column numbers are 1-based.

```lisp
(defvar *table*
  '(("name" "age" "city")
    ("Alice" "30" "NY")
    ("Bob"   "25" "LA")
    ("Carol" "35" "SF")))

;; Select rows 1 and 3
(cl-csv:select-by-fragment *table* "row=1,3")
; => (("Alice" "30" "NY") ("Carol" "35" "SF"))

;; Select column 1 (name) for all rows, keeping the header
(cl-csv:select-by-fragment *table* "col=1" :include-header t)
; => (("name") ("Alice") ("Bob") ("Carol"))

;; Select a specific cell range
(cl-csv:select-by-fragment *table* "cell=1-1,2-2")
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

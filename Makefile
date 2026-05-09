ENV?=development

## NOTE: run sbcl loading the setting the current path
## on the `ql:*local-project-directories*`.
LISP?=sbcl

LISPFLAGS=--noinform --non-interactive

.PHONY: tests cli
tests:
	ENV=$(ENV) \
	$(LISP) \
	$(LISPFLAGS) --quit --load tests-runner.lisp

cli: clean
	$(LISP) \
	$(LISPFLAGS) \
	--eval '(require :asdf)' \
	--eval '(push #P"./" asdf:*central-registry*)' \
	--eval '(asdf:operate (quote asdf:program-op) :cl-csv.cli)' \
	--eval '(uiop:quit)'

clean:
	rm -rf cvs-to-list

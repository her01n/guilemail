default: .tested

GUILE ?= guile

.tested: email.scm test/email.scm
	hdt
	touch $@

test-remote:
	hdt remote.scm

clean:
	rm -rf .tested

GUILE_SITE_DIR ?= $(shell $(GUILE) -c "(display (%site-dir)) (newline)")

install:
	install -D --target-directory=$(GUILE_SITE_DIR) email.scm



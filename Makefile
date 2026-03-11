# shgittp v0.5.0 Makefile
PREFIX    ?= $(HOME)/.local
MANPREFIX ?= $(PREFIX)/share/man
CONFDIR   ?= $(HOME)/.config/shgittp

.PHONY: install uninstall reinstall lint help

install:
	@echo "Installing shgittp..."
	@mkdir -p $(DESTDIR)$(PREFIX)/bin
	@cp -f shgittp $(DESTDIR)$(PREFIX)/bin/shgittp
	@chmod 755 $(DESTDIR)$(PREFIX)/bin/shgittp
	@echo "  $(DESTDIR)$(PREFIX)/bin/shgittp"
	@mkdir -p $(DESTDIR)$(MANPREFIX)/man1
	@cp -f man/shgittp.1 $(DESTDIR)$(MANPREFIX)/man1/shgittp.1
	@chmod 644 $(DESTDIR)$(MANPREFIX)/man1/shgittp.1
	@echo "  $(DESTDIR)$(MANPREFIX)/man1/shgittp.1"
	@mkdir -p $(CONFDIR)
	@if [ ! -f $(CONFDIR)/config ]; then \
		cp shgittp.conf $(CONFDIR)/config; \
		echo "  $(CONFDIR)/config (created)"; \
	else \
		echo "  $(CONFDIR)/config (exists, skipped)"; \
	fi
	@echo "Done."

uninstall:
	@rm -f $(DESTDIR)$(PREFIX)/bin/shgittp
	@rm -f $(DESTDIR)$(MANPREFIX)/man1/shgittp.1
	@echo "Removed shgittp. Config left at $(CONFDIR)/"

reinstall: uninstall install

lint:
	@shellcheck -s sh -e SC2086 -e SC2034 -e SC2016 -e SC2029 -e SC2154 shgittp && echo "shellcheck: ok"

help:
	@echo "make install    Install to $(PREFIX)"
	@echo "make uninstall  Remove binary + man page"
	@echo "make lint       Run shellcheck"
	@echo ""
	@echo "Override: make PREFIX=/usr/local install"

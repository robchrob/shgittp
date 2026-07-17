# shgittp v0.6.2 Makefile
PREFIX    ?= $(HOME)/.local
MANPREFIX ?= $(PREFIX)/share/man
CONFDIR   ?= $(HOME)/.config/shgittp
BASHCOMPDIR ?= $(PREFIX)/share/bash-completion/completions

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
	@mkdir -p $(DESTDIR)$(BASHCOMPDIR)
	@cp -f completions/shgittp.bash $(DESTDIR)$(BASHCOMPDIR)/shgittp
	@chmod 644 $(DESTDIR)$(BASHCOMPDIR)/shgittp
	@echo "  $(DESTDIR)$(BASHCOMPDIR)/shgittp"
	@mkdir -p $(CONFDIR)
	@if [ ! -f $(CONFDIR)/config ]; then \
		cp shgittp.conf $(CONFDIR)/config; \
		echo "  $(CONFDIR)/config (created)"; \
	else \
		echo "  $(CONFDIR)/config (exists, skipped)"; \
	fi
	@echo "Done."
	@echo "Enable Bash completion now:"
	@echo "  . $(DESTDIR)$(BASHCOMPDIR)/shgittp"
	@echo "Add the same line to ~/.bashrc to enable it in future shells."

uninstall:
	@rm -f $(DESTDIR)$(PREFIX)/bin/shgittp
	@rm -f $(DESTDIR)$(MANPREFIX)/man1/shgittp.1
	@rm -f $(DESTDIR)$(BASHCOMPDIR)/shgittp
	@echo "Removed shgittp, man page, and Bash completion. Config left at $(CONFDIR)/"

reinstall: uninstall install

lint:
	@shellcheck -s sh -e SC2086 -e SC2034 -e SC2016 -e SC2029 -e SC2154 shgittp
	@shellcheck -s bash completions/shgittp.bash
	@echo "shellcheck: ok"

help:
	@echo "make install    Install binary, man page, config, and Bash completion"
	@echo "make uninstall  Remove binary, man page, and Bash completion"
	@echo "make lint       Run shellcheck"
	@echo ""
	@echo "Override: make PREFIX=/usr/local install"

# shgittp v0.4.1 Makefile
PREFIX ?= /usr/local
BIN_DIR = $(PREFIX)/bin
CONF_DIR = $(HOME)/.config/shgittp

.PHONY: install uninstall test

install:
	@echo "Installing shgittp..."
	@mkdir -p $(BIN_DIR)
	@cp shgittp $(BIN_DIR)/shgittp
	@chmod 755 $(BIN_DIR)/shgittp
	
	@echo "Installing config..."
	@mkdir -p $(CONF_DIR)
	@if [ ! -f $(CONF_DIR)/config ]; then \
		cp shgittp.conf $(CONF_DIR)/config; \
		echo "Created: $(CONF_DIR)/config"; \
	else \
		echo "Skipped: Config exists."; \
	fi

uninstall:
	rm -f $(BIN_DIR)/shgittp

test:
	@echo "Checking syntax..."
	@bash -n shgittp
	@echo "Syntax OK."

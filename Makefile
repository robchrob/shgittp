# shgittp v0.4.11 Makefile
BIN_DIR = $(HOME)/.bin
CONF_DIR = $(HOME)/.config/shgittp

.PHONY: install uninstall reinstall test clean run

install:
	@echo "Installing shgittp..."
	@mkdir -p $(BIN_DIR)
	@cp shgittp $(BIN_DIR)/shgittp
	@chmod 755 $(BIN_DIR)/shgittp
	@echo "Installed: $(BIN_DIR)/shgittp"
	
	@echo "Installing config..."
	@mkdir -p $(CONF_DIR)
	@if [ ! -f $(CONF_DIR)/config ]; then \
		cp shgittp.conf $(CONF_DIR)/config; \
		echo "Created: $(CONF_DIR)/config"; \
	else \
		echo "Skipped: Config exists."; \
	fi

clean:
	@echo "Removing shgittp binary..."
	@rm -f $(BIN_DIR)/shgittp
	@echo "Removing shgittp config..."
	@rm -rf $(CONF_DIR)

run:
	@./docker/manage.sh alpine-basic restart && make reinstall && shgittp -A -i -r git@github.com:robchrob/dotfiles-bare.git -b minimal -x "bash .config/setup.sh" dev@devbox

runroot:
	@./docker/manage.sh alpine-root restart && make reinstall && time shgittp -A endpoint

uninstall: clean
	@echo "Uninstall complete."

reinstall: clean install
	@echo "Reinstall complete."

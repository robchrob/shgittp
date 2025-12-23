# shgittp v0.4.5 Makefile
BIN_DIR = $(HOME)/.bin
CONF_DIR = $(HOME)/.config/shgittp

.PHONY: install uninstall reinstall test clean

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

uninstall: clean
	@echo "Uninstall complete."

reinstall: clean install
	@echo "Reinstall complete."

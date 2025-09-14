# Minecraft Plymouth Theme Makefile

.PHONY: all install uninstall clean help dry-run

all: help

install:
	@./install.sh
	@plymouth-set-default-theme -R mc
	@echo "Theme installed and activated. Reboot to see it!"

uninstall:
	@./install.sh --uninstall

dry-run:
	@./install.sh --dry-run

clean:
	@if [ -d "/usr/share/plymouth/themes/mc" ]; then \
		sudo find /usr/share/plymouth/themes/mc -name "*-[0-9]*.png" -delete 2>/dev/null || true; \
	fi

help:
	@echo "Minecraft Plymouth Theme"
	@echo ""
	@echo "Usage:"
	@echo "  sudo make install   - Install and activate theme"
	@echo "  sudo make uninstall - Remove theme"  
	@echo "  make dry-run        - Preview installation"
	@echo "  sudo make clean     - Clean generated files"
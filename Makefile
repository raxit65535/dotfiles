SHELL := /bin/bash

ROOT := $(shell pwd)
CONFIG := $(ROOT)/devbox/config.json

ifeq ($(wildcard $(ROOT)/.venv/bin/python),)
PYTHON := python3
else
PYTHON := $(ROOT)/.venv/bin/python
endif

BOOTSTRAP := $(PYTHON) $(ROOT)/devbox/bootstrap.py --config $(CONFIG)

.DEFAULT_GOAL := help

.PHONY: help symlink symlink-shell symlink-zsh symlink-zprofile symlink-aliases \
	symlink-git symlink-nvim symlink-tmux symlink-db symlink-kafka \
	symlink-work symlink-vs-agents symlink-vscode symlink-opencode \
	symlink-workflow-scripts symlink-all symlink-all-dry install-devbox install-all \
	revert-symlinks revert-symlinks-dry verify-sources link-one

help:
	@echo "Dotfiles Makefile (simple mode)"
	@echo
	@echo "Main targets:"
	@echo "  make install-all          # Install tooling + apply all configured symlinks"
	@echo "  make install-devbox       # Run devbox install tasks only"
	@echo "  make symlink-all          # Apply all configured symlinks"
	@echo "  make symlink-all-dry      # Preview all configured symlink changes"
	@echo "  make revert-symlinks      # Revert configured symlinks using backups"
	@echo "  make revert-symlinks-dry  # Preview revert"
	@echo
	@echo "Targeted symlink groups:"
	@echo "  make symlink-shell symlink-git symlink-nvim symlink-vscode symlink-opencode"
	@echo "  make symlink-workflow-scripts"
	@echo
	@echo "Ad-hoc single link (without running full suite):"
	@echo "  make link-one SRC=vscode/keybindings.json DEST='~/Library/Application Support/Code/User/keybindings.json'"

# -----------------------------------------------------------------------------
# Devbox wrappers
# -----------------------------------------------------------------------------
install-devbox:
	$(BOOTSTRAP) --mode install

symlink-all:
	$(BOOTSTRAP) --mode symlinks

symlink-all-dry:
	$(BOOTSTRAP) --mode symlinks --dry-run

revert-symlinks:
	$(BOOTSTRAP) --mode revert

revert-symlinks-dry:
	$(BOOTSTRAP) --mode revert --dry-run

install-all:
	$(BOOTSTRAP) --mode all

verify-sources:
	@jq -r '.symlinks[] | [.name,.source] | @tsv' "$(CONFIG)" | \
	while IFS=$$'\t' read -r name src; do \
		if [[ -e "$(ROOT)/$$src" ]]; then \
			printf 'OK\t%s\t%s\n' "$$name" "$$src"; \
		else \
			printf 'MISSING\t%s\t%s\n' "$$name" "$$src"; \
		fi; \
	done

# -----------------------------------------------------------------------------
# Simple symlink-* targets (similar to your preferred style)
# -----------------------------------------------------------------------------
symlink: symlink-shell symlink-git symlink-nvim symlink-tmux \
	symlink-db symlink-kafka symlink-work symlink-vs-agents symlink-vscode \
	symlink-opencode

symlink-shell: symlink-zsh symlink-zprofile symlink-aliases

symlink-zsh:
	rm -f ~/.zshrc
	ln -s $(ROOT)/shell/.zshrc ~/.zshrc

symlink-zprofile:
	rm -f ~/.zprofile
	ln -s $(ROOT)/shell/.zprofile ~/.zprofile

symlink-aliases:
	rm -f ~/.aliases
	ln -s $(ROOT)/shell/.aliases ~/.aliases

symlink-git:
	rm -f ~/.gitconfig ~/.gitconfig-raxit65535 ~/.gitconfig-work
	ln -s $(ROOT)/git/.gitconfig ~/.gitconfig
	ln -s $(ROOT)/git/.gitconfig-raxit65535 ~/.gitconfig-raxit65535
	ln -s $(ROOT)/work/.gitconfig-work ~/.gitconfig-work

symlink-nvim:
	rm -rf ~/.config/nvim
	mkdir -p ~/.config
	ln -s $(ROOT)/nvim ~/.config/nvim

symlink-tmux:
	rm -f ~/.tmux.conf
	ln -s $(ROOT)/tmux/.tmux.conf ~/.tmux.conf
	ln -s $(ROOT)/tmux/cop.sh ~/.local/bin/cop
	ln -s $(ROOT)/tmux/uncop.sh ~/.local/bin/uncop
	ln -s $(ROOT)/tmux/feature-open.sh ~/.local/bin/feature-open

symlink-db:
	rm -f ~/.db_config ~/.psqlrc ~/.usqlrc
	ln -s $(ROOT)/tools/db/.db_config ~/.db_config
	ln -s $(ROOT)/tools/db/.psqlrc ~/.psqlrc
	ln -s $(ROOT)/tools/db/.usqlrc ~/.usqlrc

symlink-snowflake:
	rm -f ~/.snow.zsh
	ln -s $(ROOT)/tools/snow/snow.zsh ~/.snow.zsh
# just in case I need to setup default snowflake session params (warehouse, database, schema, etc.) for the snow CLI tool
# ln -s $(ROOT)/tools/snow/init.sql ~/.config/snow/init.sql

symlink-kafka:
	rm -f ~/.kafka_config ~/.work_kafka_config
	ln -s $(ROOT)/tools/kafka/.kafka_config ~/.kafka_config
	ln -s $(ROOT)/work/.work_kafka_config ~/.work_kafka_config

symlink-work:
	rm -f ~/.work_db_config
	rm -f ~/.snowflake/connections.toml
	mkdir -p ~/.snowflake
	ln -s $(ROOT)/work/.work_db_config ~/.work_db_config
	ln -s $(ROOT)/work/.sf_connection.toml ~/.snowflake/connections.toml
	ln -s $(ROOT)/work/.work_zshrc ~/.work_zshrc

symlink-vs-agents:
	rm -f ~/.vs-agents
	ln -s $(ROOT)/vs-agents ~/.vs-agents

symlink-vscode:
	mkdir -p ~/Library/Application\ Support/Code/User
	rm -f ~/Library/Application\ Support/Code/User/settings.json
	rm -f ~/Library/Application\ Support/Code/User/keybindings.json
	ln -s $(ROOT)/vscode/settings.json ~/Library/Application\ Support/Code/User/settings.json
	ln -s $(ROOT)/vscode/keybindings.json ~/Library/Application\ Support/Code/User/keybindings.json

symlink-opencode:
	mkdir -p ~/.config/opencode
	rm -f ~/.config/opencode/opencode.json
	ln -s $(ROOT)/opencode/opencode.json ~/.config/opencode/opencode.json

symlink-workflow-scripts:
	mkdir -p ~/.local/bin
	rm -f ~/.local/bin/cop ~/.local/bin/uncop ~/.local/bin/feature-open
	ln -s $(ROOT)/tmux/cop.sh ~/.local/bin/cop
	ln -s $(ROOT)/tmux/uncop.sh ~/.local/bin/uncop
	ln -s $(ROOT)/tmux/feature-open.sh ~/.local/bin/feature-open

# -----------------------------------------------------------------------------
# Ad-hoc: link exactly one new config file when needed
# Example:
# make link-one SRC=pi/coding-agent.json DEST=~/.config/pi/coding-agent.json
# -----------------------------------------------------------------------------
link-one:
	@if [[ -z "$(SRC)" || -z "$(DEST)" ]]; then \
		echo "Usage: make link-one SRC=<repo-relative-path> DEST=<target-path>"; \
		exit 1; \
	fi
	@src_abs="$(ROOT)/$(SRC)"; \
	tgt_abs="$${DEST/#\~/$$HOME}"; \
	if [[ ! -e "$$src_abs" ]]; then \
		echo "Source does not exist: $$src_abs"; \
		exit 1; \
	fi; \
	mkdir -p "$$(dirname "$$tgt_abs")"; \
	rm -f "$$tgt_abs"; \
	ln -s "$$src_abs" "$$tgt_abs"; \
	echo "Linked: $$tgt_abs -> $$src_abs"

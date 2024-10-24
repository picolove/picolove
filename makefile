.PHONY: help run all 9 10 11 lint format clean test build run_build dev
.SILENT: dev

project_name := picolove

run: ## run project code with tests
	@love . --test

all: format lint test build ## format, lint, test and build project

dev: ## run project code in loop mode for easy restarting
	while true; do $(MAKE) -s run && break; done

# run specific love version
# setup environment variable with path to love executable first
9: ## run project code with test using love 0.9
	@${LOVE9} . --test
10: ## run project code with test using love 0.10
	@${LOVE10} . --test
11: ## run project code with test using love 11
	@${LOVE11} . --test

lint: ## run lua source code linter
	luacheck .

format: ## format source code
	@sed -i s/0x1234\.abcd/0x1234abcd/g test.lua
	- stylua .
	@sed -i s/0x1234abcd/0x1234\.abcd/g test.lua

clean: ## clean build files
	@echo "deleting build files ..."
	@if [ -d "build/love" ]; then \
		echo "deleting \"build/love/\" ..."; \
		rm -rf "build/love"; \
	fi
	@if [ -d "build/lovejs" ]; then \
		echo "deleting \"build/lovejs/\" ..."; \
		rm -rf "build/lovejs"; \
	fi
	@if [ -d "build/macos" ]; then \
		echo "deleting \"build/macos/\" ..."; \
		rm -rf "build/macos"; \
	fi
	@if [ -d "build/win32" ]; then \
		echo "deleting \"build/win32/\" ..."; \
		rm -rf "build/win32"; \
	fi
	@if [ -d "build/win64" ]; then \
		echo "deleting \"build/win64/\" ..."; \
		rm -rf "build/win64"; \
	fi

test: ## only run tests (todo)
	# todo implement test running

build: build-makelove ## build project distribution files

build-makelove: clean ## build project with makelove
	@makelove

build-love: clean ## build project love file only with zip
	@echo "building \"build/love/${project_name}.love\" ..."
	@if [ ! -d "build/love" ]; then \
		echo "creating directory \"build/love\""; \
		mkdir "build/love"; \
	fi
	@zip -9 -r -i@includelist.txt    "build/love/${project_name}.love" .
	@zip -9 -r -i"*.lua" -x"*/*.lua" "build/love/${project_name}.love" .

run-build: ## run project love file
	@echo "executing \"build/love/${project_name}.love\" ..."
	@love "build/love/${project_name}.love"

help: ## display help
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

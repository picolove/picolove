.PHONY: help run all 9 10 11 lint format clean test build run_build dev
.SILENT: dev

project_name := picolove

run: ## run picolove code with tests
	@love . --test

all: format lint test build ## format, lint, test and build picolove

dev: ## run picolove code in loop mode for easy restarting
	while true; do $(MAKE) -s run && break; done

# run specific love version
# setup environment variable with path to love executable first
9: ## run picolove code with test using love 0.9
	@${LOVE9} . --test
10: ## run picolove code with test using love 0.10
	@${LOVE10} . --test
11: ## run picolove code with test using love 11
	@${LOVE11} . --test

lint: ## run lua source code linter
	luacheck .

format: ## format source code
	@sed -i s/0x1234\.abcd/0x1234abcd/g test.lua
	- stylua .
	@sed -i s/0x1234abcd/0x1234\.abcd/g test.lua

clean: ## clean build files
	@echo "deleting \"build/${project_name}.love\" ..."
	@rm -f "build/${project_name}.love"
	@echo "deleting \"build/love/\" ..."
	@rm -rf "build/love"
	@echo "deleting \"build/lovejs/\" ..."
	@rm -rf "build/lovejs"
	@echo "deleting \"build/macos/\" ..."
	@rm -rf "build/macos"
	@echo "deleting \"build/win32/\" ..."
	@rm -rf "build/win32"
	@echo "deleting \"build/win64/\" ..."
	@rm -rf "build/win64"

test: ## only run tests (todo)
	# todo implement test running

build: clean ## build picolove.love file
	@echo "building \"build/${project_name}.love\" ..."
	@zip -9 -r -i@includelist.txt    "build/${project_name}.love" .
	@zip -9 -r -i"*.lua" -x"*/*.lua" "build/${project_name}.love" .

run_build: ## run picolove.love file
	@echo "executing \"build/${project_name}.love\" ..."
	@love "build/${project_name}.love"

help: ## display help
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

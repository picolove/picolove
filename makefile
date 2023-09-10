.PHONY: run all 9 10 11 lint format clean test build run_build

project_name := "picolove"

run:
	@love . --test

all: format lint test build

# run specific love version
# setup environment variable with path to love executable first
9:
	@echo "Love 9 support is WIP"
	@"${LOVE9}" . --test
10:
	@"${LOVE10}" . --test
11:
	@echo "Love 11 support is WIP"
	@"${LOVE11}" . --test

lint:
	luacheck .

format:
	@sed -i s/0x1234\.abcd/0x1234abcd/g test.lua
	stylua .
	@sed -i s/0x1234abcd/0x1234\.abcd/g test.lua

clean:
	@echo "deleting \"build/${project_name}.love\" ..."
	@rm -f build/${project_name}.love

test:
	# todo implement test running

build: clean
	@echo "building \"build/${project_name}.love\" ..."
	@zip -9 -r -i@includelist.txt    build/${project_name}.love .
	@zip -9 -r -i"*.lua" -x"*/*.lua" build/${project_name}.love .

run_build:
	@echo "executing \"build/${project_name}.love\" ..."
	@love build/${project_name}.love

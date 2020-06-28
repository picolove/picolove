.PHONY: all 9 10 11 lint build clean format test

project_name := "picolove"
# ignore subfolders for now
lua_files = $(wildcard *.lua)

all:
	@love .

# run specific love version
# setup environment variable with path to love executable first
9:
	@echo "Love 9 support is WIP"
	@"${LOVE9}" .
10:
	@"${LOVE10}" .
11:
	@echo "Love 11 support is WIP"
	@"${LOVE11}" .

lint:
	luacheck .

format:
	@$(foreach file,$(lua_files),luafmt -w replace -i 2 --use-tabs $(file);)

clean:
	@echo "deleting \"build/${project_name}.love\" ..."
	@rm -f build/${project_name}.love

test:
	# todo implement test running

build: clean
	@echo "building \"build/${project_name}.love\" ..."
	@zip -9 -r build/"${project_name}".love ./nocart.p8
	@zip -9 -r -x@excludelist.txt build/${project_name}.love .

run_build:
	@echo "executing \"build/${project_name}.love\" ..."
	@love build/${project_name}.love

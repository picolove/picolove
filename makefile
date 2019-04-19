.PHONY: all check

all:
	@love .

check:
	luacheck .

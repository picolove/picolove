.PHONY: all 10 11 check

all:
	@love .

# run specific love version
# setup environment variable with path to love executable first
10:
	@"${LOVE10}" .
11:
	@"${LOVE11}" .

check:
	luacheck .

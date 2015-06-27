WORKDIR := $(shell pwd)

METADATA = $(firstword $(wildcard .*.metadata))
APP_SPEC = $(firstword $(wildcard packaging/*.spec))
SPECS_SPEC = $(firstword $(wildcard SPECS/*.spec))
SIMPLE_SPEC = $(firstword $(wildcard *.spec))

define find-correct-makefile
if [ -f "$(METADATA)" ]; then echo "../common/Makefile.centos"; elif [ -f "$(APP_SPEC)" ]; then echo "../common/Makefile.app"; elif [ -f "$(SIMPLE_SPEC)" ]; then if grep -q '^Source:\s*.\+\.tar\.gz' $(SIMPLE_SPEC); then echo "../common/Makefile.simple"; fi; fi
endef

MAKEFILE_EXTRA := $(shell $(find-correct-makefile))

ifneq ($(MAKEFILE_EXTRA),)
include $(MAKEFILE_EXTRA)
endif

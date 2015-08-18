SPECFILE = $(firstword $(wildcard *.spec))

ifndef WORKDIR
WORKDIR := $(shell pwd)
endif

default: all

all:
	@echo "Nothing to do"

## Files used to determine which Makefile to include
METADATA = $(firstword $(wildcard .*.metadata))
APP_SPEC = $(firstword $(wildcard packaging/*.spec))
SPECS_SPEC = $(firstword $(wildcard SPECS/*.spec))
SIMPLE_SPEC = $(firstword $(wildcard *.spec))

## Routine to return Makefile to include
define find-correct-makefile
if [ -f "$(METADATA)" ]; then echo "../common/Makefile.centos"; elif [ -f "$(APP_SPEC)" ]; then echo "../common/Makefile.app"; elif [ -f "$(SPECFILE)" ]; then if [ -f sources ]; then echo "../common/Makefile.fedora"; elif [ -f sources-clearos ]; then echo "../common/Makefile.clearos"; elif grep -q '^Source0\?:\s*.\+\.tar\.gz' $(SPECFILE); then echo "../common/Makefile.simple"; fi; fi
endef

## Actually try to find the right Makefile
MAKEFILE_EXTRA := $(shell $(find-correct-makefile))

## Include Makefile if we found one to use
ifneq ($(MAKEFILE_EXTRA),)
include $(MAKEFILE_EXTRA)
endif

ifeq ($(SPECFILE),)
$(error "No spec file found")
endif 

SOURCE_RPM = $(shell rpm $(RPM_DEFINES) -q --qf "%{NAME}-%{VERSION}-%{RELEASE}.src.rpm\n" --specfile $(SPECFILE)| head -1)
ifeq ($(SOURCE_RPM),)
$(error "$(SPECFILE) doesn't produce a source rpm")
endif

# the version of the package
ifndef NAME
NAME := $(shell rpm $(RPM_DEFINES) $(DIST_DEFINES) -q --qf "%{NAME}\n" --specfile $(SPECFILE)| head -1)
endif
# the version of the package
ifndef VERSION
VERSION := $(shell rpm $(RPM_DEFINES) $(DIST_DEFINES) -q --qf "%{VERSION}\n" --specfile $(SPECFILE)| head -1)
endif
# the release of the package
ifndef RELEASE
RELEASE := $(shell rpm $(RPM_DEFINES) $(DIST_DEFINES) -q --qf "%{RELEASE}\n" --specfile $(SPECFILE)| head -1)
endif
# this is used in make patch, maybe make clean eventually.
# would be nicer to autodetermine from the spec file...
RPM_BUILD_DIR ?= $(BUILDDIR)/$(NAME)-$(VERSION)

## Override RPM_WITH_DIRS to avoid the usage of these variables.
ifndef SRCRPMDIR
SRCRPMDIR = $(WORKDIR)
endif
ifndef BUILDDIR
BUILDDIR = $(WORKDIR)
endif
ifndef RPMDIR
RPMDIR = $(WORKDIR)
endif
## SOURCEDIR is special; it has to match the CVS checkout directory,-
## because the CVS checkout directory contains the patch files. So it basically-
## can't be overridden without breaking things. But we leave it a variable
## for consistency, and in hopes of convincing it to work sometime.
ifndef SOURCEDIR
SOURCEDIR := $(shell pwd)
endif

ifdef DIST
DIST_DEFINES := --define "dist $(DIST)"
endif

# RPM with all the overrides in place;
ifndef RPM
RPM := $(shell if test -f /usr/bin/rpmbuild ; then echo rpmbuild ; else echo rpm ; fi)
endif
ifndef RPM_WITH_DIRS
RPM_WITH_DIRS = $(RPM) --define "_sourcedir $(SOURCEDIR)" \
	               --define "_builddir $(BUILDDIR)" \
	               --define "_srcrpmdir $(SRCRPMDIR)" \
	               --define "_rpmdir $(RPMDIR)"
endif

.PHONY: default all sources clean srpm rpm log prep patch rediff gimmespec help

# default target: just make sure we've got the sources
all: sources

clean:
	@git clean -ndx | sed -e 's,Would remove ,,' -e '/^Makefile$$/d' | xargs -r rm -rf

srpm: sources
	@$(RPM_WITH_DIRS) $(DIST_DEFINES) -bs $(SPECFILE)

rpm: sources
	@$(RPM_WITH_DIRS) $(DIST_DEFINES) -bb $(SPECFILE)

log:
	@(LC_ALL=C date +"* %a %b %e %Y `git config --get user.name` <`git config --get user.email`> - $(VERSION)-$(RELEASE)"; git log --pretty="format:- %s (%an)" | cat) | less

prep: sources
	$(RPM_WITH_DIRS) --nodeps -bp $(SPECFILE)

ifdef CVE
PATCHFILE := $(NAME)-$(VERSION)-CVE-$(CVE).patch
SUFFIX := cve$(shell echo $(CVE) | sed s/.*-//)
else
PATCHFILE := $(NAME)-$(VERSION)-$(SUFFIX).patch
endif

patch:
	@if test -z "$(SUFFIX)"; then echo "Must specify SUFFIX=whatever" ; exit 1; fi
	(cd $(RPM_BUILD_DIR)/.. && gendiff $(NAME)-$(VERSION) .$(SUFFIX) | filterdiff --remove-timestamps) > $(PATCHFILE) || true
	@if ! test -s $(PATCHFILE); then echo "Patch is empty!"; exit 1; fi
	@echo "Created $(PATCHFILE)"
	@git add $(PATCHFILE) || true

rediff:
	@if test -z "$(SUFFIX)"; then echo "Must specify SUFFIX=whatever" ; exit 1; fi
	@if ! test -f "$(PATCHFILE)"; then echo "$(PATCHFILE) not found"; exit 1; fi
	@mv -f $(PATCHFILE) $(PATCHFILE)\~
	@sed '/^--- /,$$d' < $(PATCHFILE)\~ > $(PATCHFILE)
	@(cd $(RPM_BUILD_DIR)/.. && gendiff $(NAME)-$(VERSION) .$(SUFFIX) | filterdiff --remove-timestamps) >> $(PATCHFILE) || true

gimmespec:
	@echo "$(SPECFILE)"

help:
	@echo "Usage: make <target>"
	@echo "Available targets are:"
	@echo " help                    Show this text"
	@echo " sources                 Download source files [default]"
	@echo " prep                    Local test rpmbuild prep"
	@echo " srpm                    Create a srpm"
	@echo " log                     Display possible changelog entry"
	@echo " clean                   Remove untracked files"
	@echo " patch SUFFIX=<suff>     Create and add a gendiff patch file"
	@echo " rediff SUFFIX=<suff>    Recreates a gendiff patch file, retaining comments"
	@echo " gimmespec               Print the name of the specfile"


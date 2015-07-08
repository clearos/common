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

# tag to export, defaulting to current tag in the spec file
ifndef TAG
TAG=$(NAME)-$(VERSION)-$(RELEASE)
endif

.PHONY: default all clean sources srpm rpm log

clean:
	@git clean -ndx | sed -e 's,Would remove ,,' -e '/^Makefile$$/d' | xargs -r rm -rf

srpm: sources
	@$(RPM_WITH_DIRS) $(DIST_DEFINES) -bs $(SPECFILE)

rpm: sources
	@$(RPM_WITH_DIRS) $(DIST_DEFINES) -bb $(SPECFILE)

log:
	@(LC_ALL=C date +"* %a %b %e %Y `git config --get user.name` <`git config --get user.email`> - VERSION"; git log --pretty="format:- %s (%an)" | cat) | less


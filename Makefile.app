SPECFILE = $(firstword $(wildcard packaging/*.spec))

RPM_DEFINES := --define "_sourcedir $(WORKDIR)" \
		--define "_specdir $(WORKDIR)" \
		--define "_builddir $(WORKDIR)" \
		--define "_srcrpmdir $(WORKDIR)" \
		--define "_rpmdir $(WORKDIR)"

RPM_WITH_DIRS = rpmbuild $(RPM_DEFINES)
QUERY_FORMAT = $(shell sed -n 's/^Source:\s*\(.*\).tar.gz/\1/ip' $(SPECFILE) | head -1)
NAME_VER = $(shell rpm $(RPM_DEFINES) -q --qf "$(QUERY_FORMAT)\n" --specfile $(SPECFILE)| head -1)
SOURCE_RPM = $(shell rpm $(RPM_DEFINES) -q --qf "%{NAME}-%{VERSION}-%{RELEASE}.src.rpm\n" --specfile $(SPECFILE)| head -1)

ifeq ($(SPECFILE),)
$(error "No spec file found for $(NAME)")
endif

ifeq ($(NAME_VER),)
$(error "$(SPECFILE) doesn't contain valid source")
endif

ifeq ($(SOURCE_RPM),)
$(error "$(SPECFILE) doesn't produce a source rpm")
endif

.PHONY: sources srpm $(SOURCE_RPM) $(NAME_VER)

$(NAME_VER).tar.gz:
	@git archive --format tar.gz --prefix $(NAME_VER)/ --output $(NAME_VER).tar.gz HEAD

sources: $(NAME_VER).tar.gz

$(SOURCE_RPM): $(NAME_VER).tar.gz
	@$(RPM_WITH_DIRS) --nodeps -bs $(SPECFILE)

srpm: $(SOURCE_RPM)

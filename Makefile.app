SPECFILE = $(firstword $(wildcard packaging/*.spec))

sources:
	@git archive --prefix $(NAME)-$(VERSION)/ --output $(NAME)-$(VERSION).tar.gz HEAD

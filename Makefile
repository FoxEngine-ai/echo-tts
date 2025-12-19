.PHONY: build publish release bump-patch bump-minor bump-major clean help

VERSION_FILE := pyproject.toml
INIT_FILE := src/echo_tts/__init__.py
CURRENT_VERSION := $(shell grep -Po 'version = "\K[^"]+' $(VERSION_FILE))

help:
	@echo "echo-tts build & release"
	@echo ""
	@echo "Current version: $(CURRENT_VERSION)"
	@echo ""
	@echo "Usage:"
	@echo "  make build              Build Docker image"
	@echo "  make publish            Upload to PyPI"
	@echo "  make release V=0.2.0    Set version, build, and publish"
	@echo "  make bump-patch         Bump patch version (0.1.1 -> 0.1.2)"
	@echo "  make bump-minor         Bump minor version (0.1.1 -> 0.2.0)"
	@echo "  make bump-major         Bump major version (0.1.1 -> 1.0.0)"
	@echo "  make clean              Remove Docker build cache"

build:
	docker build -t echo-tts . --no-cache

publish:
	docker compose run --rm publish

set-version:
ifndef V
	$(error V is not set. Usage: make set-version V=0.2.0)
endif
	@echo "Setting version to $(V)"
	sed -i 's/version = "[^"]*"/version = "$(V)"/' $(VERSION_FILE)
	sed -i 's/__version__ = "[^"]*"/__version__ = "$(V)"/' $(INIT_FILE)
	@echo "Version updated to $(V)"

bump-patch:
	$(eval NEW_VERSION := $(shell echo $(CURRENT_VERSION) | awk -F. '{print $$1"."$$2"."$$3+1}'))
	@$(MAKE) set-version V=$(NEW_VERSION)

bump-minor:
	$(eval NEW_VERSION := $(shell echo $(CURRENT_VERSION) | awk -F. '{print $$1"."$$2+1".0"}'))
	@$(MAKE) set-version V=$(NEW_VERSION)

bump-major:
	$(eval NEW_VERSION := $(shell echo $(CURRENT_VERSION) | awk -F. '{print $$1+1".0.0"}'))
	@$(MAKE) set-version V=$(NEW_VERSION)

release: 
ifdef V
	@$(MAKE) set-version V=$(V)
endif
	@$(MAKE) build
	@$(MAKE) publish
	@echo "Released version $$(grep -Po 'version = "\K[^"]+' $(VERSION_FILE))"

clean:
	docker builder prune -f

.PHONY: build publish release bump-patch bump-minor bump-major clean help test

VERSION_FILE := pyproject.toml
INIT_FILE := src/echo_tts/__init__.py
CURRENT_VERSION := $(shell grep -Po 'version = "\K[^"]+' $(VERSION_FILE))
TEST_DEVICE ?= cuda
TEST_STEPS ?= 4
TEST_SEQUENCE_LENGTH ?= 128
TEST_OUTPUT_DIR ?= output
TEST_DOCKER_ARGS ?=

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
	@echo "  make test               Run audio generation test in Docker"
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

test:
	@mkdir -p $(TEST_OUTPUT_DIR)
	@docker image inspect echo-tts >/dev/null 2>&1 || $(MAKE) build
	docker run --rm \
		$(TEST_DOCKER_ARGS) \
		-v "$(PWD)":/work -w /work \
		-e ECHO_TTS_RUN_AUDIO_TEST=1 \
		-e ECHO_TTS_TEST_DEVICE=$(TEST_DEVICE) \
		-e ECHO_TTS_TEST_STEPS=$(TEST_STEPS) \
		-e ECHO_TTS_TEST_SEQUENCE_LENGTH=$(TEST_SEQUENCE_LENGTH) \
		-e ECHO_TTS_TEST_OUTPUT_DIR=$(TEST_OUTPUT_DIR) \
		--entrypoint bash \
		echo-tts -lc "pip install -q pytest && pytest -k audio_generation"

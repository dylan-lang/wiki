all: build

.PHONY: build

OPEN_DYLAN_DIR = $(realpath $(dir $(realpath $(shell which dylan-compiler)))/..)

APP_SOURCES = $(wildcard */*.dylan) \
              $(wildcard */*.lid)

REGISTRIES = `pwd`/registry:`pwd`/ext/http/registry

ifeq (, $(wildcard .git))
check-submodules:
else
check-submodules:
	@for sms in `git submodule status --recursive | grep -v "^ " | cut -c 1`; do \
	  if [ "$$sms" != "x" ]; then \
	    echo "**** ERROR ****"; \
	    echo "One or more submodules is not up to date."; \
	    echo "Please run 'git submodule update --init --recursive'."; \
	    exit 1; \
	  fi; \
	done;
endif

build: $(APP_SOURCES) check-submodules
	OPEN_DYLAN_USER_REGISTRIES=$(REGISTRIES) dylan-compiler -build wiki

clean:
	rm -rf _build/


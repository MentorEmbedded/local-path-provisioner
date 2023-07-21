TARGETS := $(shell ls scripts)
GO_FILES ?= $$(find . -name '*.go' | grep -v generated)
GO_VERSION ?= 1.17
USE_DAPPER ?= 1
UNAME := $(shell uname -m)
SHELL = /bin/bash
WD := $(shell pwd)
export TOOLPATH := $(WD)
export GOROOT := $(TOOLPATH)/bin/go
export PATH := $(TOOLPATH)/bin:$(GOROOT)/bin:$(PATH)

ifeq ($(UNAME),x86_64)
	ARCH = amd64
else
        ifeq ($(UNAME),aarch64)
	        ARCH = arm64
        endif
endif

.dapper:
	@echo Downloading dapper
	@curl -sL https://releases.rancher.com/dapper/latest/dapper-`uname -s`-`uname -m` > .dapper.tmp
	@@chmod +x .dapper.tmp
	@./.dapper.tmp -v
	@mv .dapper.tmp .dapper

.nodapper:
	$(info Checking essential build aspects.)
	@if [ ! -d $(WD)/bin ] ; then \
		mkdir $(WD)/bin ; \
	fi
	@if [ ! -d $(WD)/dist ] ; then \
		mkdir $(WD)/dist ; \
	fi
	$(info Checking go version for compatibility.)
	@if [ ! -d $(GOROOT) ] ; then \
		echo "No go found, fetching compatible version." ; curl -sL https://go.dev/dl/go$(GO_VERSION).linux-$(ARCH).tar.gz | tar -C $$PWD/bin -zxf - ; \
	else \
		case "$$(go version)" in \
			*$(GO_VERSION)* ) echo "Compatible go version found." ;; \
			* ) echo "Go appears to be " $$(go version) ; echo "Incompatible or non-functional go found, fetching compatible version." ; curl -sL https://go.dev/dl/go$(GO_VERSION).linux-$(ARCH).tar.gz | tar -C $$PWD/bin -zxf - ;; \
		esac \
	fi

ifeq ($(strip $(USE_DAPPER)),1)
$(TARGETS): .dapper
	./.dapper $@
else

# We call clean ourselves in a separate target and we are reproducing the ci
# call here in our 'build' case.
$(filter-out clean ci default, $(TARGETS)): .nodapper
	case $@ in \
		build ) cd scripts ; ./build ;; \
		* ) ./scripts/$@ ;; \
	esac

ci: build
	$(info No additional ci steps required.)

default: build
	$(info No additional default steps required.)

clean:
	rm -fr bin dist

endif

.PHONY: deps
deps:
	go mod tidy

.DEFAULT_GOAL := default

.PHONY: $(TARGETS)

build/data:
	mkdir -p $@

format:
	gofmt -s -l -w $(GO_FILES)
	goimports -w $(GO_FILES)

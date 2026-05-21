# Makefile for Quadrants Haxe API documentation generated with Dox.

HAXE ?= haxe
DOX ?= haxelib run dox
BUILDDIR ?= build
XMLDIR := $(BUILDDIR)/xml
HTMLDIR := $(BUILDDIR)/html
XMLFILE := $(XMLDIR)/quadrants.xml
DOX_TITLE ?= Quadrants Haxe API
DOX_DESCRIPTION ?= Haxe/HashLink bindings for the Quadrants programming language.
DOX_INCLUDE ?= ^quadrants
DOX_EXCLUDE ?= ^quadrants\\.macro
DOXOPTS ?=

.PHONY: help html xml clean

help:
	@echo "Quadrants documentation targets:"
	@echo "  make html   Generate Haxe API docs in $(HTMLDIR) with Dox"
	@echo "  make xml    Generate Haxe XML docs in $(XMLDIR)"
	@echo "  make clean  Remove $(BUILDDIR)"

html: xml
	@rm -rf "$(HTMLDIR)"
	@$(DOX) -i "$(XMLDIR)" -o "$(HTMLDIR)" --title "$(DOX_TITLE)" --toplevel-package quadrants -in "$(DOX_INCLUDE)" -ex "$(DOX_EXCLUDE)" -D description "$(DOX_DESCRIPTION)" $(DOXOPTS)

xml: $(XMLFILE)

$(XMLFILE): dox.hxml ../bindings/hashlink/haxe/quadrants/*.hx ../bindings/hashlink/haxe/quadrants/macro/*.hx
	@mkdir -p "$(XMLDIR)"
	@$(HAXE) dox.hxml

clean:
	@rm -rf "$(BUILDDIR)"

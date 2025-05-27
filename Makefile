# @TODO Setup
# @TODO Documentation
# and you're done
# @TODO (optional) get filter name from git

#
# User settings
# -----------------------------------------------------------------------------
#
# Filter name
#
# 	Set the filter name here, or use `make ... NAME=myname` 
#	or `touch myname.lua`. 
FILTER_NAME :=$(patsubst %.lua,%,$(wildcard *.lua))
#
# Source file folder and name
#
#   If SRC_DIR is set, the filter file is built from a source file and modules
#   present in SRC_DIR. Building from source requires Lua Code Combine. Imported
#   modules must be in $(SRC_DIR). To prevent rebuild, set $(SRC_DIR) to "" on
#   the command line. By default the source's main file's name is the same as the
#	filter's. To use another set SRC_MAIN (without `.lua` extension).
SRC_DIR ?= src
SRC_MAIN ?= $(FILTER_NAME)
#
# Pandoc formats for output
#
#   One or more Pandoc formats. Should be acceptable values of the pandoc `-t`
#   flag, and should not be empty. Can be set by the user. 
#	
ifeq "$(FORMAT)" ""
FORMAT ?= native
endif
#
# System commands. Adjustable from the command line. Useful for e.g. Docker.
#
PANDOC ?= pandoc
QUARTO ?= quarto
DIFF ?= diff
LUACC ?= luacc
#
# Test file suffixes
#
#   Customize expected out file suffixes. Should not be empty. This Makefile
#   relies on them to create and recognize expected output files. They are
#   placed between basename and extension, as in `example.pandoc_expected.html`.
PANDOC_EXPECTED = .pandoc_expected
QUARTO_EXPECTED = .quarto_expected
#
# Pandoc defaults files suffix
#
#   Customize Pandoc defaults files suffi (default empty). When rendering a file
#   example.md with Pandoc this Makefile checks whether there is a corresponding
#   example$DEFAULTS.yaml file, and if found, uses it as Pandoc defaults (CLI
#   paramters). 
DEFAULTS = 
#
# Documentation files
#
#   Documentation generated with Pandoc or Quarto. If both QUARTO_DOCS and
#   PANDOC_DOCS are non-empty the former is used.
#   - Quarto: set QUARTO_DOCS to a Quarto project directory, e.g. `docs`
#     containing a _quarto.yml file. QUARTO_DOCS must be at the root. The
#     documentation will be rendered running
#     
#        quarto render --output-dir ../_site -t html
#
#     in the QUARTO_DOCS folder. 
#   - Pandoc: set PANDOC_DOCS to a single markdown file, e.g. 'docs/manual.md`
#	  or `README.md`. The documentation will be rendered running
#
#        pandoc $(PANDOC_DOCS) -o _site/index.html -L $(FILTER_FILE) -L docs.lua
#	  
#     By default the filter is applied to the documentation itself, for
#     illustration purposes. If this should not be so set APPLY_FILTER_TO_DOCS
#     to 'no'. 
QUARTO_DOCS = 
PANDOC_DOCS = doc/manual.md
APPLY_FILTER_TO_DOCS ?= yes 
#
# Sample Pandoc output to be included in the documentation
#
#     Pandoc-generated documentation optionally includes a sample output.
#     The sample output must be a html or a text format (not PDF or other binary).
#     Set source file, destination format and (optionally) defaults file.
# 	  The sample is generated with:
#
#		  pandoc -L $(FILTER_FILE) -d $(DOCS_SAMPLE_DEFAULTS)
#				-o _site/output.$(DOCS_SAMPLE_FORMAT)
DOCS_SAMPLE_SRC = examples/example.md
DOCS_SAMPLE_FORMAT ?= html
DOCS_SAMPLE_DEFAULTS = examples/example.docs.yaml
#
# Internal settings
# -----------------------------------------------------------------------------
# Use a POSIX sed with ERE ('v' is specific to GNU sed)
SED := sed $(shell sed v </dev/null >/dev/null 2>&1 && echo " --posix") -E
#
# If $(FILTER_NAME) wasn't set but $(SRC_MAIN)$ was, use the latter
ifeq "$(FILTER_NAME)" ""
ifneq "$(SRC_MAIN)" ""
FILTER_NAME = $(SRC_MAIN)
endif
endif
#
# File locations
#
#   If we have a Pandoc filter only, the filter is at the root. If we have a
#   Quarto extension, we need it in the Quarto extensions folder. Due to the way
#   Quarto downloads extensions, we can't use a symlink to root in the Quarto
#   extension folder, so we will do the other way round.
ifneq "$(FILTER_NAME)" ""
QUARTO_EXT_DIR = _extensions/$(FILTER_NAME)
QUARTO_EXT_FILE = $(QUARTO_EXT_DIR)/$(FILTER_NAME).lua
ROOT_FILE = $(FILTER_NAME).lua
FILTER_FILE = $(wildcard $(QUARTO_EXT_FILE))
ifeq "$(FILTER_FILE)" ""
FILTER_FILE = $(ROOT_FILE)
endif
endif
#
# Find filter's source files
#
ifneq "$(SRC_DIR)" ""
ifneq "$(SRC_MAIN)" ""
SRC_FILE = $(wildcard $(SRC_DIR)/$(SRC_MAIN).lua)
define FIND_SRC_MODULES
find $(SRC_DIR) -type f -name "*.lua" -and ! -path "$(SRC_FILE)"
endef
SRC_MODULES_FILES := $(shell $(FIND_SRC_MODULES))
SRC_MODULES := $(SRC_MODULES_FILES:$(SRC_DIR)/%.lua=%)
endif
endif
#
# Current version
#
#	Using the latest Git tag to version the Quarto extension.
VERSION = $(shell git tag --sort=-version:refname --merged | head -n1 | \
						 sed -e 's/^v//' | tr -d "\n")
ifeq "$(VERSION)" ""
VERSION = 0.0.0
endif
#
# GitHub repository; used to setup the filter.
REPO_PATH = $(shell git remote get-url origin | sed -e 's%.*github\.com[/:]%%')
REPO_NAME = $(shell git remote get-url origin | sed -e 's%.*/%%')
USER_NAME = $(shell git config user.name)
#
# Setup example outputs and tests
# 
# Lists of .md and .qmd files in relevant folders
define FIND_MD_TEST_FILES
find . -type d \( -name 'test*' -o -name 'example*' \) -exec find {} -type f -name "*.md" \;
endef
define FIND_QMD_TEST_FILES
find . -type d \( -name 'test*' -o -name 'example*' \) -exec find {} -type f -name "*.qmd" \;
endef
MD_TEST_FILES = $(shell $(FIND_MD_TEST_FILES))
QMD_TEST_FILES = $(shell $(FIND_QMD_TEST_FILES))
# 
# List existing expected output files. The `test` target depends on this
# to ensure that tests are re-run if expected files have changed.
MD_EXPECTED_FILES = $(foreach file,$(MD_TEST_FILES),$(wildcard $(dir $(file))$(basename $(notdir $(file)))$(PANDOC_EXPECTED).*))
QMD_EXPECTED_FILES = $(foreach file,$(QMD_TEST_FILES),$(wildcard $(dir $(file))$(basename $(notdir $(file)))$(QUARTO_EXPECTED).*))
#
# Error and warning messages
#
# echo $(...) wouldn't work as expansions have linebreaks. We export to shell
# variables and use echo $$... instead.
define ERROR_MISSING_FILTER_FILE
[ERROR] Aborting: cannot find the filter file nor a source file to build it.\
I need a `.lua` file at the root, or in Quarto's extension folder. If you have\
a source file in a separate folder try:

    make build SRC_DIR=path/to/source SRC_MAIN=filename_without_lua_extension

endef
export ERROR_MISSING_FILTER_FILE
define ERROR_EMPTY_FILES_AND_NO_SOURCE
[ERROR] Aborting: no filter file found; `$(ROOT_FILE)` symlinks
to `$(QUARTO_EXT_FILE)` and I cannot find a source file to rebuild
them from. Did you delete the quarto extension without making 
a copy of the filter? 
endef
export ERROR_EMPTY_FILES_AND_NO_SOURCE
define ERROR_TWO_FILTER_FILES
[ERROR] Found two filter files: `$(ROOT_FILE)` and `$(QUARTO_EXT_FILE)`. 
That should not happen: the former should be a symlink to the latter. 
Did you create a new root file by mistake?
endef
export ERROR_TWO_FILTER_FILES
define FIX_ERROR_TWO_FILTER_FILES_NO_SOURCE
To fix this, make sure `$(QUARTO_EXT_FILE)` is the up-to-date version and run:

    rm $(ROOT_FILE)
    ln -s $(QUARTO_EXT_FILE) $(ROOT_FILE)

endef
export FIX_ERROR_TWO_FILTER_FILES_NO_SOURCE
define ERROR_SRC_FILE_MISSING
[ERROR] Cannot build the filter: no source file found at $(SRC_DIR)/$(SRC_MAIN).lua.
If you do not intend to build from a source file set SRC_DIR to nothing in Makefile.
endef
export ERROR_SRC_FILE_MISSING
define ERROR_LUACC_MISSING
[ERROR] LuaCC not found. LuaCC is needed to build the filter from
multiple source files. Available from LuaRocks [1]. You may also
adjust the variable `LUACC` in this Makefile. Otherwise make
your source a single .lua file.

[1] https://luarocks.org/modules/mihacooper/luacc

endef
export ERROR_LUACC_MISSING
define ERROR_PANDOC_SUFFIX_MISSING
[ERROR] No extension defined for expected outputs (PANDOC_EXPECTED in Makefile).
Cannot safely generate Pandoc expected results.
endef
export ERROR_PANDOC_SUFFIX_MISSING
define ERROR_QUARTO_SUFFIX_MISSING
[ERROR] No extension defined for expected outputs (QUARTO_EXPECTED in Makefile).
Cannot safely generate Pandoc expected results.
endef
export ERROR_QUARTO_SUFFIX_MISSING
#
# Help
# -----------------------------------------------------------------------------
#
## Show available targets
# Comments preceding "simple" targets (those which do not use macro name or
# start with underscore or dot) and introduced by two dashes are used as their
# description.
.PHONY: help
help:
	@tabs 22 ; $(SED) -ne \
	'/^## / h ; /^[^_.$$#][^ ]+:/ { G; s/^(.*):.*##(.*)/\1@\2/; P ; h ; }' \
	$(MAKEFILE_LIST) | tr @ '\t'

#
# Build
# ---------------------------------------------------------------
#
## Builds the filter from the source folder, if available
#
#   Ensures the filter files are present and well set. Dependency of all targets
#   that depend on the filter file.
#
#   If SRC_DIR is set, we add a $(FILTER_FILE) target to build the filter file.
.PHONY: build
build: $(FILTER_FILE)
	@if [[ "$(SRC_FILE)" = "" && "$(FILTER_FILE)" = "" ]]; then \
		echo "$$ERROR_MISSING_FILTER_FILE"; \
		exit 1; \
	fi
# checks when not building a file
ifeq "$(SRC_DIR)" ""
	@if [[ -L "$(ROOT_FILE)" && ! -e "$(QUARTO_EXT_FILE)" ]]; then \
		echo "$$ERROR_EMPTY_FILES_AND_NO_SOURCE"; \
		exit 1; \
	fi
	@if [[ -f "$(QUARTO_EXT_FILE)" && -f "$(ROOT_FILE)" && ! -L "$(ROOT_FILE)" ]]; then \
		echo "$$ERROR_TWO_FILTER_FILES" ; \
		echo "$$FIX_ERROR_TWO_FILTER_FILES_NO_SOURCE"; \
		echo "Aborting."; \
		exit 1; \
	fi
endif

# $(FILTER_FILE) target to build the source. If not building from source,
# simply check that the setup is ok. Otherwise, if source contains multiple files,
# use luacc, otherwise copy. If Quarto extension, build there and symlink from
# root. Due to the way Quarto downloads extensions, we can't use a symlink to
# root in the quarto extension folder.
ifneq "$(FILTER_FILE)" ""
ifneq "$(SRC_DIR)" ""
$(FILTER_FILE): $(SRC_FILE) $(SRC_MODULES_FILES)
# Check that we have a source and that there's no duplicate file
	@if [[ -f "$(QUARTO_EXT_FILE)"" && -f "$(ROOT_FILE)"" && ! -L "$(ROOT_FILE)" ]]; then \
		echo "$$ERROR_TWO_FILTER_FILES" ; \
		read -p "Overwrite $(QUARTO_EXT_FILE) and $(ROOT_FILE)? (y/N) " REPLY; \
		if [[ "$$REPLY" == "Y" || "$$REPLY" == "y" ]]; then \
			echo "Ovewriting both files..."; \
		else \
			echo "Cancelled building the filter."; \
			exit 1; \
		fi; \
	elif [[ ! -f "$(SRC_FILE)" ]]; then \
		echo "$$ERROR_SRC_FILE_MISSING"; \
		exit 1; \
	elif [[ -L "$(ROOT_FILE)" && ! -e "$(QUARTO_EXT_FILE)" ]]; then \
		rm -f $(ROOT_FILE); \
	fi
# If compiling, check that LuaCC is present
	@if [ "$(SRC_MODULES)" != "" ]; then \
		if f! command -v $(LUACC) &> /dev/null ; then \
			echo "$$ERROR_LUACC_MISSING"; \
			exit 1; \
		fi; \
	fi
# Building process. 
#   - copy or, if there are src modules, compile
#	- if created in Quarto ext folder, link
	@if [ "$(SRC_MODULES)" = "" ]; then \
		echo "Copying $(SRC_DIR)/$(SRC_MAIN).lua to $(FILTER_FILE)"; \
		cp $(SRC_DIR)/$(SRC_MAIN).lua $(FILTER_FILE); \
	else \
		echo "Compiling $(SRC_DIR)/$(SRC_MAIN).lua to $(FILTER_FILE)"; \
		$(LUACC) -o $(FILTER_FILE) -i $(SRC_DIR) \
			$(SRC_DIR)/$(SRC_MAIN) $(SRC_MODULES); \
	fi
	@if [ -d "$(QUARTO_EXT_DIR)" ]; then \
		rm $(ROOT_FILE); \
		ln -s $(QUARTO_EXT_FILE) $(ROOT_FILE); \
	fi
endif
endif

# 
# Tests
# ---------------------------------------------------------------
#
## Run all tests, checking outputs against expected output files
.PHONY: test
test: ptest qtest

## Run all Pandoc tests
.PHONY: ptest
ptest: build $(MD_TEST_FILES) $(MD_EXPECTED_FILES)
ifneq "$(PANDOC_EXPECTED)" ""
	@for file in $(MD_TEST_FILES); do \
		dir=$$(dirname $$file); \
		name=$$(basename $$file .md); \
		if [ -f $$dir/$$name"$(DEFAULTS).yaml" ]; then \
			opts="-d $$dir/$$name""$(DEFAULTS).yaml" ; \
			opts_msg="using defaults file"; \
		else \
			opts="-L $(FILTER_FILE)" ; \
			opts_msg="" ;\
		fi; \
		for fmt in $(FORMAT) ; do \
			echo Comparing against $$dir/$$name"$(PANDOC_EXPECTED)."$$fmt $$opts_msg...; \
			$(PANDOC) $$file $$opts -t $$fmt | $(DIFF) $$dir/$$name"$(PANDOC_EXPECTED)."$$fmt -; \
			if [ $$? -eq 1 ]; then \
				echo Fail: cannot reproduce $$dir/$$name"$(QUARTO_EXPECTED)."$$fmt ;\
				exit 1;\
			fi; \
		done;\
	done; 
else
	@echo "$$ERROR_PANDOC_SUFFIX_MISSING"
endif

## Run all Quarto tests
.PHONY: qtest
qtest: build $(QMD_TEST_FILES) $(QMD_EXPECTED_FILES) 
ifneq "$(QUARTO_EXPECTED)" ""
	@for file in $(QMD_TEST_FILES); do \
		dir=$$(dirname $$file); \
		name=$$(basename $$file .qmd); \
		for fmt in $(FORMAT) ; do \
			echo Comparing against $$dir/$$name"$(QUARTO_EXPECTED)."$$fmt ...; \
			(cd $$dir && quarto render $$name.qmd -t $$fmt --output - | $(DIFF) $$name"$(QUARTO_EXPECTED)."$$fmt - ;); \
			if [ $$? -eq 1 ]; then \
				echo Fail: cannot reproduce $$dir/$$name"$(QUARTO_EXPECTED)."$$fmt ;\
				exit 1;\
			fi; \
		done;\
	done; 
else
	@echo $$ERROR_QUARTO_SUFFIX_MISSING
endif

## Generate expected outputs
# This target **must not** be a dependency of the `test` target, as that
# would cause it to be regenerated on each run, making the test
# pointless.
.PHONY: generate
generate: pgenerate qgenerate

## Generate Pandoc expected outputs
.PHONY: pgenerate
pgenerate: build $(MD_TEST_FILES)
ifneq "$(PANDOC_EXPECTED)" ""
	@for file in $(MD_TEST_FILES); do \
		dir=$$(dirname $$file); \
		name=$$(basename $$file .md); \
		if [ -f $$dir/$$name"$(DEFAULTS).yaml" ]; then \
			opts="-d $$dir/$$name""$(DEFAULTS).yaml" ; \
			opts_msg="using defaults file"; \
		else \
			opts="-L $(FILTER_FILE)" ; \
			opts_msg="" ;\
		fi; \
		for fmt in $(FORMAT) ; do \
			echo Rendering $$dir/$$name"$(PANDOC_EXPECTED)."$$fmt $$opts_msg...; \
			$(PANDOC) $$file $$opts -t $$fmt -o $$dir/$$name"$(PANDOC_EXPECTED)."$$fmt; \
		done;\
	done; 
else
	@echo "$$ERROR_PANDOC_SUFFIX_MISSING"
endif

## Generate Quarto expected outputs
# 	Quarto only renders in pwd, so we need to change directories.
.PHONY: qgenerate
qgenerate: build $(QMD_TEST_FILES)
ifneq "$(QUARTO_EXPECTED)" ""
	@for file in $(QMD_TEST_FILES); do \
		dir=$$(dirname $$file); \
		name=$$(basename $$file .qmd); \
		for fmt in $(FORMAT) ; do \
			echo Rendering $$dir/$$name"$(QUARTO_EXPECTED)."$$fmt ...; \
			(cd $$dir && quarto render $$name.qmd -t $$fmt -o $$name"$(QUARTO_EXPECTED)."$$fmt;); \
		done;\
	done; 
else
	@echo "$$ERROR_QUARTO_SUFFIX_MISSING"
endif

#
# Documentation
# -----------------------------------------------------------------------------
#
## Generate documentation website in _site
.PHONY: manual
manual: build _site/$(FILTER_NAME).lua _site/index.html
#
## Alias of `manual`
.PHONY: website
website: manual
#
## Alias of `manual`
.PHONY: doc
doc: manual
#
# Symlink copy the filter file in _site for inclusion in docs
_site/$(FILTER_NAME).lua: $(FILTER_FILE)
	@mkdir -p _site
	@(cd _site && ln -sf ../$< $(FILTER_NAME).lua)

ifneq "$(QUARTO_DOCS)" ""
_site/index.html: $(QUARTO_DOCS) $(DOCS_SAMPLE_SRC) $(DOCS_SAMPLE_DEFAULTS)
	@mkdir -p _site
	(cd $(QUARTO_DOCS) && $(QUARTO) render --output-dir ../_site/ -t html)
else
ifneq "$(PANDOC_DOCS)" ""
_site/index.html: $(PANDOC_DOCS) _site/output.$(DOCS_SAMPLE_FORMAT) \
	.tools/docs.lua _site/style.css
	@mkdir -p _site
	@cp .tools/anchorlinks.js _site
ifneq "$(APPLY_FILTER_TO_DOCS)" "no"
	@$(PANDOC) --standalone \
	    --lua-filter=.tools/docs.lua \
	    --lua-filter=.tools/anchorlinks.lua \
		--lua-filter=$(FILTER_FILE) \
	    --metadata=sample-file:$(DOCS_SAMPLE_SRC) \
	    --metadata=result-file:_site/output.$(DOCS_SAMPLE_FORMAT) \
	    --metadata=code-file:$(ROOT_FILE) \
	    --css=style.css \
	    --toc \
	    --output=$@ $<
else
	@$(PANDOC) --standalone \
	    --lua-filter=.tools/docs.lua \
	    --lua-filter=.tools/anchorlinks.lua \
	    --metadata=sample-file:$(DOCS_SAMPLE_SRC) \
	    --metadata=result-file:_site/output.$(DOCS_SAMPLE_FORMAT) \
	    --metadata=code-file:$(ROOT_FILE) \
	    --css=style.css \
	    --toc \
	    --output=$@ $<
endif
endif # ends if $(PANDOC_DOCS)
endif # ends if $(QUARTO_DOCS)

_site/style.css:
	@mkdir -p _site
	curl --output $@ \
	    'https://cdn.jsdelivr.net/npm/water.css@2/out/water.min.css'

_site/output.$(DOCS_SAMPLE_FORMAT):  build $(DOCS_SAMPLE_SRC) $(DOCS_SAMPLE_DEFAULTS)
ifneq "$(DOCS_SAMPLE_SRC)" ""
	@mkdir -p _site
ifneq "$(DOCS_SAMPLE_DEFAULTS)" ""
	@$(PANDOC) $(DOCS_SAMPLE_SRC) \
	    --defaults=$(DOCS_SAMPLE_DEFAULTS) \
		--to=$(DOCS_SAMPLE_FORMAT) \
	    --output=$@
else
	@$(PANDOC) $(DOCS_SAMPLE_SRC) \
		--to=$(DOCS_SAMPLE_FORMAT) \
	    --output=$@
endif
endif

#
# Quarto extension
# -----------------------------------------------------------------------------
#
#
## Creates or updates the quarto extension
.PHONY: quarto-extension
quarto-extension: $(QUARTO_EXT_DIR)/_extension.yml $(QUARTO_EXT_FILE)
#
# This may change, so re-create the file every time
$(QUARTO_EXT_DIR)/_extension.yml: $(QUARTO_EXT_FILE) $(QUARTO_EXT_DIR)
	@printf 'Creating %s\n' $@
	@printf 'name: %s\n' "$(FILTER_NAME)" > $@
	@printf 'author: %s\n' "$(USER_NAME)" >> $@
	@printf 'version: %s\n'  "$(VERSION)" >> $@
	@printf 'contributes:\n  filters:\n    - %s\n' $(FILTER_NAME).lua >> $@
#
# The filter file must be below the quarto _extensions folder: a symlink in the
# extension would not work due to the way in which quarto installs extensions.
# Only define if $(FILTER_FILE) is nonempty and distinct from
# $(QUARTO_EXT_FILE): otherwise the $(FILTER_FILE) target is defined in the
# build section. 
ifneq "$(FILTER_FILE)" ""
ifneq "$(QUARTO_EXT_FILE)" "$(FILTER_FILE)"
$(QUARTO_EXT_FILE): build $(QUARTO_EXT_DIR)
	@if [ ! -L $(ROOT_FILE) ]; then \
		mv $(ROOT_FILE) $(QUARTO_EXT_FILE) && \
		ln -s $(QUARTO_EXT_FILE) $(ROOT_FILE);\
	fi
endif
endif

$(QUARTO_EXT_DIR):
	@mkdir -p $@

#
# Release
# -----------------------------------------------------------------------------
#
# Before release (re)generate expected results and Quarto extension if present
# For the help to display we need a single `release` target; hence to ensure it
# conditionally depends on `quarto-extension` we have to set up a variable. 
ifeq "$(FILTER_FILE)" "$(QUARTO_EXT_FILE)"
QUARTO_EXTENSION_TARGET = quarto-extension
else
QUARTO_EXTENSION_TARGET =
endif
## Sets a new release (uses VERSION macro if defined)
.PHONY: release
release: build generate $(QUARTO_EXTENSION_TARGET)
	git commit -am "Release $(FILTER_NAME) $(VERSION)"
	git tag v$(VERSION) -m "$(FILTER_NAME) $(VERSION)"
	@echo 'Do not forget to push the tag back to github with `git push --tags`'
#
# Set up (normally used only once)
# -----------------------------------------------------------------------------
#
## Update filter name
# .PHONY: update-name
# update-name:
# 	sed -i'.bak' -e 's/greetings/$(FILTER_NAME)/g' README.md
# 	sed -i'.bak' -e 's/greetings/$(FILTER_NAME)/g' test/test.yaml
# 	rm README.md.bak test/test.yaml.bak

## Set everything up (must be used only once)
.PHONY: setup
setup:
	@echo "Welcome to the filter setup"
	@echo "Not ready yet"
	@exit 1

# OLDsetup: update-name
# 	git mv greetings.lua $(REPO_NAME).lua
# 	@# Crude method to updates the examples and links; removes the
# 	@# template instructions from the README.
# 	sed -i'.bak' \
# 	    -e 's/greetings/$(REPO_NAME)/g' \
# 	    -e 's#tarleb/lua-filter-template#$(REPO_PATH)#g' \
#       -e '/^\* \*/,/^\* \*/d' \
# 	    README.md
# 	sed -i'.bak' -e 's/greetings/$(REPO_NAME)/g' test/test.yaml
# 	sed -i'.bak' -e 's/Albert Krewinkel/$(USER_NAME)/' LICENSE
# 	rm README.md.bak test/test.yaml.bak LICENSE.bak

#
# Clean
# -----------------------------------------------------------------------------
#
## Clean regenerable documentation files
.PHONY: clean
clean: 
	rm -f _site/output.md _site/index.html _site/style.css
#
## Clean all regenerable files, including expected results
.PHONY: xclean
xclean: clean
	rm -f $(MD_EXPECTED_FILES) $(QMD_EXPECTED_FILES)


all: casper_modules_list derecho_modules_list

casper_modules_list: utils/update_module_list.sh
	@echo "Updating Casper module list..."
	@./$< casper > casper_modules_list.tmp
	@mv -f casper_modules_list.tmp docs/compute-systems/casper/casper-modules-list.md

derecho_modules_list: utils/update_module_list.sh
	@echo "Updating Derecho module list..."
	@./$< derecho > derecho_modules_list.tmp
	@mv -f derecho_modules_list.tmp docs/compute-systems/derecho/derecho-modules-list.md


tags TAGS etags:
	if [ "x$(STR)" != "x" ]; then \
	  echo "Tagging files containing $(STR)" ; \
	  git grep -l $(STR) ; \
	  etags $$(git grep -l $(STR)) ; \
	else \
	  echo "Tagging all git managed files:" ; \
	  git ls-tree -r HEAD --name-only | egrep ".md|.yaml" | grep -v "confluence_migration"; \
	  etags $$(git ls-tree -r HEAD --name-only | egrep ".md|.yaml" | grep -v "confluence_migration") ; \
	fi

# this rule invokes emacs on each source file to remove trailing whitespace.
delete-trailing-whitespace:
	for file in *.txt *.yaml $$(find ./docs -name "*.md" -type f); do \
	  echo $$file ; \
	  emacs -batch $$file --eval '(delete-trailing-whitespace)' -f save-buffer 2>/dev/null ; \
	done

dos2unix:
	for file in *.yaml $$(find ./docs -name "*.md" -type f); do \
	  echo $$file ; \
	  dos2unix $$file ; \
	done

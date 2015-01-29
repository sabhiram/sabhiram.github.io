# Makefile
all: help

help:
	@echo ""
	@echo "Helper Makefile for random bundle tasks"
	@echo ""
	@echo "* make serve - Run the jekyll engine on this site, and host it over 0.0.0.0:4040"
	@echo ""

serve:
	bundle exec jekyll serve -H 0.0.0.0 -D

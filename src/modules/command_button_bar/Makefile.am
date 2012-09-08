include $(srcdir)/../module.mk

module_in_files = command_button_bar.module.in
module_files = $(module_in_files:.module.in=.module) 
module_DATA = $(module_files)

module_LTLIBRARIES = libcommand_button_bar.la
libcommand_button_bar_la_SOURCES = command_button_bar.vala

pkgdata_DATA = command_button_bar.config.json

EXTRA_DIST = $(module_in_files)
CLEANFILES = $(module_files)

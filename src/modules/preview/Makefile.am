include $(srcdir)/../module.mk

module_in_files = preview.module.in
module_files = $(module_in_files:.module.in=.module) 
module_DATA = $(module_files)

module_LTLIBRARIES = libpreview.la
libpreview_la_SOURCES = preview.vala

EXTRA_DIST = $(module_in_files)
CLEANFILES = $(module_files)

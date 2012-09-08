include $(srcdir)/../module.mk

module_in_files = filters.module.in
module_files = $(module_in_files:.module.in=.module) 
module_DATA = $(module_files)

module_LTLIBRARIES = libfilters.la
libfilters_la_SOURCES = filters.vala

EXTRA_DIST = $(module_in_files)
CLEANFILES = $(module_files)

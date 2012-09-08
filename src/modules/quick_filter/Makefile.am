include $(srcdir)/../module.mk

module_in_files = quick_filter.module.in
module_files = $(module_in_files:.module.in=.module) 
module_DATA = $(module_files)

module_LTLIBRARIES = libquick_filter.la
libquick_filter_la_SOURCES = quick_filter.vala

EXTRA_DIST = $(module_in_files)
CLEANFILES = $(module_files)

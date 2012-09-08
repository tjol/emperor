include $(srcdir)/../module.mk

module_in_files = sort.module.in
module_files = $(module_in_files:.module.in=.module) 
module_DATA = $(module_files)

module_LTLIBRARIES = libsort.la
libsort_la_SOURCES = sort.vala

EXTRA_DIST = $(module_in_files)
CLEANFILES = $(module_files)

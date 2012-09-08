include $(srcdir)/../module.mk

module_in_files = basic_columns.module.in
module_files = $(module_in_files:.module.in=.module) 
module_DATA = $(module_files)

module_LTLIBRARIES = libbasic_columns.la
libbasic_columns_la_SOURCES = basic_columns.vala

EXTRA_DIST = $(module_in_files)
CLEANFILES = $(module_files)

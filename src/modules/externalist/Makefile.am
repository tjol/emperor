include $(srcdir)/../module.mk

module_in_files = externalist.module.in
module_files = $(module_in_files:.module.in=.module) 
module_DATA = $(module_files)

module_LTLIBRARIES = libexternalist.la
libexternalist_la_SOURCES = externalist.vala

EXTRA_DIST = $(module_in_files)
CLEANFILES = $(module_files)

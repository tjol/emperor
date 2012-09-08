include $(srcdir)/../module.mk

module_in_files = monitor_directory.module.in
module_files = $(module_in_files:.module.in=.module) 
module_DATA = $(module_files)

module_LTLIBRARIES = libmonitor_directory.la
libmonitor_directory_la_SOURCES = monitor_directory.vala

EXTRA_DIST = $(module_in_files)
CLEANFILES = $(module_files)

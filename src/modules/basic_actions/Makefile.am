include $(srcdir)/../module.mk

module_in_files = basic_actions.module.in
module_files = $(module_in_files:.module.in=.module) 
module_DATA = $(module_files)

module_LTLIBRARIES = libbasic_actions.la
libbasic_actions_la_SOURCES = basic_actions.vala

EXTRA_DIST = $(module_in_files)
CLEANFILES = $(module_files)

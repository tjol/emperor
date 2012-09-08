include $(srcdir)/../module.mk

module_in_files = volume_toolbar.module.in
module_files = $(module_in_files:.module.in=.module) 
module_DATA = $(module_files)

module_LTLIBRARIES = libvolume_toolbar.la
libvolume_toolbar_la_SOURCES = volume_toolbar.vala

EXTRA_DIST = $(module_in_files)
CLEANFILES = $(module_files)

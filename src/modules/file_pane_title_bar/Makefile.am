include $(srcdir)/../module.mk

module_in_files = file_pane_title_bar.module.in
module_files = $(module_in_files:.module.in=.module) 
module_DATA = $(module_files)

module_LTLIBRARIES = libfile_pane_title_bar.la
libfile_pane_title_bar_la_SOURCES = file_pane_title_bar.vala

EXTRA_DIST = $(module_in_files)
CLEANFILES = $(module_files)

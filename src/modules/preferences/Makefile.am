include $(srcdir)/../module.mk

module_in_files = preferences.module.in
module_files = $(module_in_files:.module.in=.module) 
module_DATA = $(module_files)

res_DATA = prefs_dialog.ui prefs_objects.json

module_LTLIBRARIES = libpreferences.la
libpreferences_la_SOURCES = preferences.vala columns.vala mouse.vala

EXTRA_DIST = $(module_in_files) $(res_DATA)
CLEANFILES = $(module_files)

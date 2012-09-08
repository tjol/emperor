include $(srcdir)/../module.mk

module_in_files = file_transfer.module.in
module_files = $(module_in_files:.module.in=.module) 
module_DATA = $(module_files)

module_LTLIBRARIES = libfile_transfer.la
libfile_transfer_la_SOURCES = file_transfer.vala

EXTRA_DIST = $(module_in_files)
CLEANFILES = $(module_files)

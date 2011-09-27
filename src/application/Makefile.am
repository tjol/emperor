bin_PROGRAMS=emperor

if HAVE_LIBNOTIFY
MOUNTWAITER_VALA = mountwait-notification.vala
# This is needed for dist to work. The configure script removes it.
mountwait-dialog.c:
	touch mountwait-dialog.c
else
MOUNTWAITER_VALA = mountwait-dialog.vala
endif


emperor_SOURCES=emperor_core.vala file_pane.vala \
		module_delegates.vala file_info_column.vala \
		main_window.vala module_registry.vala \
		user_interface_manager.vala input_dialog.vala \
		external_applications.vala prefs_machine.vala \
		$(MOUNTWAITER_VALA) \
		archive_types.vala keysyms_stamp.c

emperor_VALAFLAGS=@VALAFLAGS@ \
		  @GMODULE_VALAFLAGS@ @LIBXML_VALAFLAGS@ @LIBNOTIFY_VALAFLAGS@ \
		  --vapi=emperor.vapi --header=emperor.h
emperor_CFLAGS=@GLOBAL_CFLAGS@ \
	       @GMODULE_CFLAGS@ @LIBXML_CFLAGS@ @LIBNOTIFY_CFLAGS@
emperor_LDADD=@GTK_LIBS@ @GMODULE_LIBS@ @LIBXML_LIBS@ @GEE_LIBS@ @LIBNOTIFY_LIBS@

EXTRA_DIST = emperor.vapi emperor.h \
	     gen_keysym_files.py keynames.h keynames.c gdkkeysyms.vapi \
	     gio-2.0.vapi libnotify.vapi

MAINTAINERCLEANFILES = emperor.vapi emperor.h \
		       keynames.c gdkkeysyms.vapi \
		       keysyms_stamp.c

keysyms_stamp.c: gen_keysym_files.py
	python3 gen_keysym_files.py
	touch keysyms_stamp.c

gdkkeysyms.vapi: keysyms_stamp.c



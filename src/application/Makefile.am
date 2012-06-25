bin_PROGRAMS=emperor

if HAVE_LIBNOTIFY
NOTIFY_COMPONENTS_VALA = mountwait-notification.vala
else
NOTIFY_COMPONENTS_VALA = 
endif


emperor_SOURCES=emperor_core.vala file_pane.vala \
		module_delegates.vala file_info_column.vala \
		main_window.vala module_registry.vala \
		user_interface_manager.vala input_dialog.vala \
		external_applications.vala prefs_machine.vala \
		mountwait.vala mountwait-dialog.vala \
		$(NOTIFY_COMPONENTS_VALA) \
		archive_types.vala

emperor_VALAFLAGS=@VALAFLAGS@ \
		  @GMODULE_VALAFLAGS@ @LIBXML_VALAFLAGS@ @LIBNOTIFY_VALAFLAGS@ \
		  --vapi=emperor.vapi --header=emperor.h
emperor_CFLAGS=@GLOBAL_CFLAGS@ \
	       @GMODULE_CFLAGS@ @LIBXML_CFLAGS@ @LIBNOTIFY_CFLAGS@ \
	       -DPROGRAMNAME_LOCALEDIR=\"${PROGRAMNAME_LOCALEDIR}\"
emperor_LDADD=@GTK_LIBS@ @GMODULE_LIBS@ @LIBXML_LIBS@ @GEE_LIBS@ @LIBNOTIFY_LIBS@

EXTRA_DIST = emperor.vapi emperor.h

MAINTAINERCLEANFILES = emperor.vapi emperor.h



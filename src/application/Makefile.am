bin_PROGRAMS=emperor

if HAVE_LIBNOTIFY
NOTIFY_COMPONENTS_VALA = mountwait-notification.vala
else
NOTIFY_COMPONENTS_VALA = 
endif


emperor_SOURCES=emperor_core.vala \
        configuration_manager.vala \
		module_registry.vala \
		module_delegates.vala \
		user_interface_manager.vala \
		mount_manager.vala \
        file_pane_interface.vala \
        abstract_file_pane.vala \
        file_pane_with_toolbars.vala \
        table_file_pane.vala \
		file_info_column.vala \
		main_window.vala \
		input_dialog.vala \
		external_applications.vala \
		mountwait.vala \
		mountwait-dialog.vala \
		$(NOTIFY_COMPONENTS_VALA) \
		archive_types.vala

emperor_VALAFLAGS=@VALAFLAGS@ \
		  @GMODULE_VALAFLAGS@ @LIBNOTIFY_VALAFLAGS@ \
		  --vapi=emperor.vapi --header=emperor.h
emperor_CFLAGS=@GLOBAL_CFLAGS@ \
	       @GMODULE_CFLAGS@ @LIBNOTIFY_CFLAGS@ \
	       -DPROGRAMNAME_LOCALEDIR=\"${PROGRAMNAME_LOCALEDIR}\"
emperor_LDADD=@GTK_LIBS@ @GMODULE_LIBS@ @GEE_LIBS@ \
			  @LIBNOTIFY_LIBS@ @JSON_GLIB_LIBS@

EXTRA_DIST = emperor.vapi emperor.h

MAINTAINERCLEANFILES = emperor.vapi emperor.h



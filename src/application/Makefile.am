bin_PROGRAMS=emperor

emperor_SOURCES=emperor_core.vala file_pane.vala \
		module_delegates.vala file_info_column.vala \
		main_window.vala module_registry.vala \
		user_interface_manager.vala input_dialog.vala \
		external_applications.vala \
		#keynames.c

emperor_VALAFLAGS=@VALAFLAGS@ \
		  @GMODULE_VALAFLAGS@ @LIBXML_VALAFLAGS@ \
		  --vapi=emperor.vapi --header=emperor.h
emperor_CFLAGS=@GLOBAL_CFLAGS@ \
	       @GMODULE_CFLAGS@ @LIBXML_CFLAGS@
emperor_LDADD=@GTK_LIBS@ @GMODULE_LIBS@ @LIBXML_LIBS@ @GEE_LIBS@

EXTRA_DIST = emperor.vapi emperor.h \
	     gen_keysym_files.py keynames.h keynames.c gdkkeysyms.vapi
MAINTAINERCLEANFILES = emperor.vapi emperor.h \
		       keynames.c gdkkeysyms.vapi

keynames.c: gen_keysym_files.py
	python3 gen_keysym_files.py

gdkkeysyms.vapi: keynames.c



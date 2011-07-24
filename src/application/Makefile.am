bin_PROGRAMS=emperor

emperor_SOURCES=emperor_core.vala file_pane.vala \
		main_window.vala module_registry_impl.vala \
		user_interface_manager.vala
emperor_VALAFLAGS=@VALAFLAGS@ \
		  @GMODULE_VALAFLAGS@ @LIBXML_VALAFLAGS@ \
		  @EMPEROREXT_VALAFLAGS@
emperor_CFLAGS=@GLOBAL_CFLAGS@ \
	       @GMODULE_CFLAGS@ @LIBXML_CFLAGS@ \
	       @EMPEROREXT_CFLAGS@
emperor_LDADD=@GTK_LIBS@ @GMODULE_LIBS@ @LIBXML_LIBS@ @GEE_LIBS@ ../interfaces/libemperor_ext.a


nodist_noinst_HEADERS = emperor_config.h
MOSTLYCLEANFILES = emperor_config.h
EXTRA_DIST = emperor_config.vapi

emperor_config.h: Makefile
	echo >emperor_config.h "#define EMPEROR_CONFIG_PACKAGE_NAME \"$(PACKAGE)\""
	echo >>emperor_config.h "#define EMPEROR_CONFIG_PACKAGE_VERSION \"$(PACKAGE_VERSION)\""
	echo >>emperor_config.h "#define EMPEROR_CONFIG_PACKAGE_VERSION_NAME \"$(PACKAGE_VERSION_NAME)\""
	echo >>emperor_config.h "#define EMPEROR_CONFIG_DATA_DIR \"$(pkgdatadir)\""
	echo >>emperor_config.h "#define EMPEROR_CONFIG_MODULE_DIR \"$(pkglibdir)\""
	echo >>emperor_config.h "#define EMPEROR_CONFIG_GETTEXT_PACKAGE GETTEXT_PACKAGE"
	echo >>emperor_config.h "#define EMPEROR_CONFIG_PROGRAMNAME_LOCALEDIR PROGRAMNAME_LOCALEDIR"

nodist_noinst_HEADERS = emperor_config.h
MOSTLYCLEANFILES = emperor_config.h
EXTRA_DIST = emperor_config.vapi

emperor_config.h:
	echo >emperor_config.h "#define EMPEROR_CONFIG_MODULE_DIR \"$(pkglibdir)\""


pkgdata_DATA = config.xml apps.xml

EXTRA_DIST = $(pkgdata_DATA)

_config_xml_strings.h: config.xml
	echo >_config_xml_strings.h "STRINGS =" && \
	grep < config.xml xtitle | \
	    sed -r 's/^.*xtitle=(".*?").*$$/_(\1)/' \
	    >> _config_xml_strings.h && \
	echo >> _config_xml_strings.h ";"


#!/bin/sh

echo +++ Running intltoolize ... &&
intltoolize --force --copy &&
cat >>po/Makefile.in.in <<EOF

../xml/_config_xml_strings.h:
	cd ../xml && \$(MAKE) _config_xml_strings.h

EOF
echo +++ Running libtoolize ... &&
libtoolize --copy &&
echo +++ Running aclocal ... &&
aclocal -I m4 &&
echo +++ Running autoconf ... &&
autoconf && 
echo +++ Running automake --add-missing ... &&
automake --add-missing --copy --gnu &&
echo +++ Running automake ... &&
automake Makefile src/Makefile &&
touch config/config.rpath &&
echo You may now run ./configure ||
( echo ERROR.; false )


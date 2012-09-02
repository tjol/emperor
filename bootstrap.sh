#!/bin/sh

mkdir -p m4 &&
echo +++ Running intltoolize ... &&
intltoolize --force --copy &&
cat >>po/Makefile.in.in <<EOF

../data/_column_names.h:
	cd ../data && \$(MAKE) _column_names.h

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
echo You may now run ./configure ||
( echo ERROR.; false )


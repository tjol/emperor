#!/bin/sh

echo +++ Running intltoolize ... &&
intltoolize -f &&
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


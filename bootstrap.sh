#!/bin/sh

echo +++ Creating config/ ... &&
mkdir -p config &&
echo +++ Running aclocal ... &&
aclocal &&
echo +++ Running libtoolize ... &&
libtoolize &&
echo +++ Running autoconf ... &&
autoconf && 
echo +++ Running automake --add-missing ... &&
automake --add-missing &&
echo +++ Running automake ... &&
automake --foreign Makefile src/Makefile &&
echo You may now run ./configure ||
( echo ERROR.; false )


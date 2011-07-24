SUBDIRS = src

EXTRA_DIST = bootstrap.sh config.xml
ACLOCAL_AMFLAGS = -I m4

run: all-recursive
	src/application/emperor --module-path=src/modules/.libs -c config.xml


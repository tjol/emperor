SUBDIRS = po src xml

pkgdata_DATA = crown_icon_256.png

EXTRA_DIST = config/config.rpath  bootstrap.sh crown_icon_256.png
ACLOCAL_AMFLAGS = -I m4

run: all-recursive
	src/application/emperor --module-path=src/modules/.libs -c xml

dist-hook:
	@if test -d "$(srcdir)/.git"; \
	    then \
		echo Creating ChangeLog && \
		( cd "$(srcdir)" && \
		  config/missing --run perl config/gitlog-to-changelog ) > ChangeLog.tmp && \
		mv -f ChangeLog.tmp $(distdir)/ChangeLog \
		|| ( rm -f ChangeLog.tmp ; \
		     echo Failed to generate ChangeLog >&2 ); \
	    else \
		echo A git clone is required to generate a ChangeLog. >&2; \
	    fi

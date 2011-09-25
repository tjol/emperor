SUBDIRS = po src xml data

EXTRA_DIST = config/config.rpath \
	     config/gitlog-to-changelog \
	     bootstrap.sh

ACLOCAL_AMFLAGS = -I m4

run: all-recursive
	EMPEROR_RES_LOCATION=data src/application/emperor --module-path=src/modules/.libs -c xml

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


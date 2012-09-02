SUBDIRS = data po src

INTLTOOL_FILES = intltool-extract.in \
		 intltool-merge.in \
		 intltool-update.in

EXTRA_DIST = config/gitlog-to-changelog \
	     bootstrap.sh \
	     $(INTLTOOL_FILES)

DISTCLEANFILES = intltool-extract \
		 intltool-merge \
		 intltool-update \
		 po/.intltool-merge-cache

MAINTAINERCLEANFILES = $(INTLTOOL_FILES)

ACLOCAL_AMFLAGS = -I m4

run: all-recursive
	EMPEROR_RES_LOCATION=data src/application/emperor --module-path=src/modules/.libs -c data

debug-nemiver: all-recursive
	nemiver --env="EMPEROR_RES_LOCATION=data" src/application/emperor --module-path=src/modules/.libs -c data

debug-gdb: all-recursive
	EMPEROR_RES_LOCATION=data gdb --args src/application/emperor --module-path=src/modules/.libs -c data

debug:
	( which nemiver >/dev/null 2>&1 && $(MAKE) debug-nemiver ) \
	    || ( which gdb >/dev/null 2>&1 && $(MAKE) debug-gdb ) \
	    || ( echo >&2 "ERROR: Don't know how to debug: neither nemiver nor gdb found."; false )

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

valadoc:
	valadoc $(VALA_PACKAGES) $(GMODULE_VALAFLAGS) $(LIBXML_VALAFLAGS) $(LIBNOTIFY_VALAFLAGS) \
		    --private --internal --force -o valadoc --package-name=emperor \
		    src/application/*.vala

valadoc-public:
	valadoc $(VALA_PACKAGES) $(GMODULE_VALAFLAGS) $(LIBXML_VALAFLAGS) $(LIBNOTIFY_VALAFLAGS) \
		    --force -o valadoc-public --package-name=emperor \
		    src/application/*.vala

.PHONY: valadoc valadoc-public run debug-gdb debug-nemiver debug


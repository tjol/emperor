SUBDIRS = po src xml

iconsdir = $(datadir)/icons/hicolor/256x256/apps
icons_DATA = emperor-fm.png

desktopdir = $(datadir)/applications
desktop_DATA = emperor.desktop

EXTRA_DIST = config/config.rpath  bootstrap.sh  \
	     $(icons_DATA) \
	     emperor.desktop.in

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

gtk_update_icon_cache = gtk-update-icon-cache -f -t $(datadir)/icons/hicolor

install-data-hook: update-icon-cache
uninstall-hook: update-icon-cache
update-icon-cache:
	@-if test -z "$(DESTDIR)"; then \
		echo "Updating Gtk icon cache."; \
		$(gtk_update_icon_cache); \
	else \
		echo "*** Icon cache not updated.  After (un)install, run this:"; \
		echo "***   $(gtk_update_icon_cache)"; \
	fi


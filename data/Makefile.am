iconsdir = $(datadir)/icons/hicolor/256x256/apps
icons_DATA = emperor-fm.png

desktopdir = $(datadir)/applications
desktop_DATA = emperor.desktop

resdir = $(pkgdatadir)/res
res_DATA = eject.png downarrow.png @PACKAGE_VERSION_NAME@.png

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


EXTRA_DIST = $(icons_DATA) \
	     $(res_DATA) \
	     emperor.desktop.in


iconsdir = $(datadir)/icons/hicolor/256x256/apps
icons_DATA = emperor-fm.png

desktopdir = $(datadir)/applications
desktop_in_files = emperor-template.desktop.in
desktop_DATA = emperor.desktop
@INTLTOOL_DESKTOP_RULE@

resdir = $(pkgdatadir)/res
res_DATA = eject.png downarrow.png @PACKAGE_VERSION_NAME@.png

pkgdata_DATA = config.json column-types.json

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

_column_names.h: column-types.json
	python $(srcdir)/gen_header.py < $< > $@

emperor.desktop: emperor-template.desktop
	sed -e "s|@""prefix""@|$(prefix)|g" < $< > $@

CLEANFILES = emperor.desktop emperor-template.desktop
MAINTAINERCLEANFILES = _column_names.h
EXTRA_DIST = $(icons_DATA) \
	     $(res_DATA) \
	     $(pkgdata_DATA) \
	     $(desktop_in_files) \
	     _column_names.h


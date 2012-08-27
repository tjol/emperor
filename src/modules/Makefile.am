AM_CFLAGS=@GLOBAL_CFLAGS@ @EMPEROREXT_CFLAGS@
AM_VALAFLAGS=@EMPEROREXT_VALAFLAGS@
AM_LDFLAGS=-avoid-version

pkglib_LTLIBRARIES = libbasic_columns.la libbasic_actions.la \
		     libfile_transfer.la \
		     libsort.la libfilters.la \
		     libvolume_toolbar.la \
		     libnetmenu.la \
		     libmonitor_directory.la \
		     libexternalist.la \
		     libpreview.la \
		     libquick_filter.la \
		     libfile_pane_title_bar.la

libbasic_columns_la_SOURCES=basic_columns.vala

libsort_la_SOURCES=sort.vala

libbasic_actions_la_SOURCES=basic_actions.vala

libfilters_la_SOURCES=filters.vala

libfile_transfer_la_SOURCES=file_transfer.vala

libvolume_toolbar_la_SOURCES=volume_toolbar.vala

libquick_filter_la_SOURCES=quick_filter.vala

libfile_pane_title_bar_la_SOURCES=file_pane_title_bar.vala

libnetmenu_la_SOURCES=netmenu.vala
libnetmenu_la_VALAFLAGS=$(AM_VALAFLAGS) @LIBXML_VALAFLAGS@
libnetmenu_la_CFLAGS=$(AM_CFLAGS) @LIBXML_CFLAGS@

libmonitor_directory_la_SOURCES=monitor_directory.vala

libexternalist_la_SOURCES=externalist.vala

libpreview_la_SOURCES=preview.vala


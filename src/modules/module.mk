AM_CFLAGS=@GLOBAL_CFLAGS@ @EMPEROREXT_CFLAGS@
AM_VALAFLAGS=@EMPEROREXT_VALAFLAGS@
AM_LDFLAGS=-avoid-version
moduledir=$(pkglibdir)
resdir = $(pkgdatadir)/res

%.module: %.module.in $(INTLTOOL_MERGE) $(wildcard $(top_srcdir)/po/*po) ; $(INTLTOOL_MERGE) $(top_srcdir)/po $< $@ -d -u -c $(top_builddir)/po/.intltool-merge-cache

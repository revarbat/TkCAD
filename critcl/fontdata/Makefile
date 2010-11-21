PKGNAME=fontdata
SRCS=$(PKGNAME).tcl
DOCS=$(subst .tcl,_docs.txt,$(SRCS))

CRITCL=critcl.kit
WISHAPP=$(HOME)/dev/Tcl/head/build/Applications/Utilities/Wish.app
LIBDIR=lib
TEADIR=Contents/lib

PKGINSTDIR=$(WISHAPP)/$(TEADIR)/$(PKGNAME)
PKG=$(LIBDIR)/$(PKGNAME)


all: $(PKG) $(DOCS)

$(PKG): $(SRCS)
	$(CRITCL) -pkg $<

install: $(PKG)
	rm -rf $(PKGINSTDIR)
	cp -r $(PKG) $(PKGINSTDIR)

%_docs.txt: %.tcl
	grep "^##" $< | cut -c4- > $@
	
docs: $(DOCS)

clean:
	rm -rf $(DOCS) $(PKG) $(LIBDIR)



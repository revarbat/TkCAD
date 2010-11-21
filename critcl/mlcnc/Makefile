PKGNAME=mlcnc_critcl
SRCS=mlcnc_critcl.tcl
DOCS=$(subst .tcl,_docs.txt,$(SRCS))
CXXSRCS=Line.cc testbench.cc
CXXOBJS=$(subst .cc,.o,$(CXXSRCS))

CRITCL=critcl.kit
WISHAPP=$(HOME)/dev/Tcl/head/build/Applications/Utilities/Wish.app
LIBDIR=lib
TEADIR=Contents/lib

PKGINSTDIR=$(WISHAPP)/$(TEADIR)/$(PKGNAME)1.0
PKGINSTDIR2=$(HOME)/dev/Tcl/head/build/$(PKGNAME)1.0
PKG=$(LIBDIR)/$(PKGNAME)

CXX=g++
CXXFLAGS=
INCLUDES=


all: testbench

tclpkg: $(PKG) $(DOCS)

$(PKG): $(SRCS)
	$(CRITCL) -pkg $<

install: $(PKG)
	rm -rf $(PKGINSTDIR) $(PKGINSTDIR2)
	cp -r lib/mlcnc_critcl $(PKGINSTDIR)
	cp -r lib/mlcnc_critcl $(PKGINSTDIR2)

%_docs.txt: %.tcl
	grep "^##" $< | cut -c4- > $@
	
docs: $(DOCS)

clean:
	rm -rf $(DOCS) $(PKG) $(LIBDIR) $(CXXOBJS)

.cc.o:
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c -o $@ $<

testbench: $(CXXOBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^

